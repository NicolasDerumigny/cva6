/*
 * Test of the HPDCACHE_WRITEBACK_STATUS register.
 *
 * Core 0 writes a buffer, leaving all its cachelines dirty in the cache, then
 * activates the pinning of that buffer: this writes back the dirty cachelines
 * which should have been pinned, i.e. the ones dirtied before the activation.
 * Core 1 polls HPDCACHE_WRITEBACK_STATUS until it is set, then checks that no
 * cacheline of the buffer is cached anymore and that reading the buffer back,
 * which cannot hit, gives what core 0 wrote. Reading it again must then cache
 * and pin all its cachelines.
 *
 * The walk is the lowest priority user of the cache directory, so the cache
 * keeps answering requests during it: core 1 starts polling before core 0
 * triggers the walk, so it must see the status cleared then set again after a
 * non-zero number of polls, which cannot happen if the walk blocks the cache.
 * The cache is shared by the two cores, so core 1 inspects what core 0 wrote.
 */

#include <stdio.h>

#include "common.h"
#include "csr.h"
#include "util.h"
#include "vm.h"

uint64_t stage = 0;

/* Set by core 1 when it starts polling the writeback status register, so that
 * core 0 triggers the writeback while core 1 is polling it */
uint64_t polling = 0;

/* One cacheline per set: the buffer stays far from saturating the sets of the
 * pinned region */
#define WB_NB_LINES (64)
#define WB_NB_WORDS (WB_NB_LINES * HPDCACHE_CACHELINE_SIZE / 8)

static volatile uint64_t buffer[WB_NB_WORDS] __attribute__((aligned(4096)));

/* The test is run in real address mode then in virtual address mode */
#define WB_NB_PHASES (2)

/* Maximum number of polls before declaring the writeback stalled: the walk
 * lasts three cycles per directory entry, and it yields the cache directory
 * to the requests waiting for the cache pipeline, plus the time to write the
 * region back to memory */
#define WB_POLL_MAX (100000)

/* Maximum number of iterations of the handshakes between the two cores: one
 * core must not wait forever for the other one if it has given up */
#define WB_SYNC_MAX (1000000)

/* Content of a buffer word, depending on the phase of the test: each phase
 * checks a different pattern, so a match cannot come from a previous phase */
static uint64_t wb_pattern(uint64_t word, uint64_t phase) {
    return (word * 0x9e3779b97f4a7c15UL) ^ (phase * 0xd1342543de82ef95UL);
}

/* Handshake between the cores on the stage they have reached: bounded so that a
 * core which gives up does not make the other one wait until the timeout */
static int wait_stage(uint64_t expected) {
    uint64_t polls = 0;

    while (__sync_load(&stage) != expected) {
        if (++polls > WB_SYNC_MAX) {
            printf("Error: timeout waiting for stage %lu\n", expected);
            return 1;
        }
    }

    return 0;
}

/* Core 0: wait until core 1 announces that it polls the writeback status
 * register, so that the writeback is triggered while core 1 is polling it */
static int wait_polling(uint64_t expected) {
    uint64_t polls = 0;

    while (__sync_load(&polling) != expected) {
        if (++polls > WB_SYNC_MAX) {
            printf("Error: timeout waiting for core 1 to poll the status\n");
            return 1;
        }
    }

    return 0;
}

static volatile void *wb_line(uint64_t line) {
    return (volatile void *)&buffer[line * (HPDCACHE_CACHELINE_SIZE / 8)];
}

/* Check the presence in the cache directory of every cacheline of the buffer
 * (`expected` is the state they must have). Returns the number of mismatches.
 * Inside the pinned region, a cacheline is present if its tag matches and it is
 * pinned: the tag of an invalidated entry is left untouched */
static uint64_t check_region_cached(int expected) {
    uint64_t errors = 0;

    for (uint64_t line = 0; line < WB_NB_LINES; line++) {
        volatile void *addr = wb_line(line);
        uint64_t set = get_set(addr);
        int present = 0;

        for (uint64_t way = 0; way < HPDCACHE_NB_WAYS; way++) {
            if (is_cl_present(set, way, addr)) {
                present = 1;
            }
        }
        if (present != (expected ? 1 : 0)) {
            printf("Error: cacheline %p %s the cache (set %lu)\n", addr,
                   expected ? "is missing from" : "is still present in", set);
            errors++;
        }
    }

    return errors;
}

/* Core 0: dirty all the cachelines of the buffer, then write back an empty
 * region to set the status register. The only event which can clear it
 * afterwards is the activation of the pinning under test */
static int dirty_buffer(uint64_t phase) {
    uint64_t sum = 0;
    uint64_t polls = 0;
    int ret = 0;

    /* Start from a clean state: the following stores are the only way the
     * buffer can come back in the cache, and they come back dirty */
    for (uint64_t line = 0; line < WB_NB_LINES; line++) {
        invalidate_cacheline((void *)wb_line(line));
    }
    fence();

    for (uint64_t i = 0; i < WB_NB_WORDS; i++) {
        buffer[i] = wb_pattern(i, phase);
    }
    fence();

    /* Make sure the stores have reached the cache before modifying the pinned
     * region: they are the data which must be written back */
    for (uint64_t i = 0; i < WB_NB_WORDS; i++) {
        sum += buffer[i];
    }
    if (sum == 0) {
        printf("Error: writeback buffer has not been filled\n");
        ret++;
    }
    fence();

    /* All the cachelines of the buffer must be present in the cache, otherwise
     * there is nothing to write back and the test is meaningless. The region is
     * not pinned yet, so only the tags are meaningful */
    for (uint64_t line = 0; line < WB_NB_LINES; line++) {
        volatile void *addr = wb_line(line);
        if (find_cl_way(get_set(addr), addr) < 0) {
            printf("Error: cacheline %p of the buffer is not cached\n", addr);
            ret++;
        }
    }

    /* Write back an empty region, which only sets the status register */
    init_csr_region(buffer, 0);
    while (!get_writeback_status()) {
        if (++polls > WB_POLL_MAX) {
            printf("Error: HPDCACHE_WRITEBACK_STATUS has never been set by the "
                   "writeback of the empty region\n");
            return 1;
        }
    }

    return ret;
}

/* Core 0: activate the pinning of the buffer, which writes back the dirty
 * cachelines the buffer holds in the cache */
static int pin_buffer(void) {
    s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t *)HPDCACHE_CSR_BASE;
    int ret = 0;

    /* Activate the pinning of the buffer: this is what triggers the writeback
     */
    init_csr_region(buffer, WB_NB_LINES);

    if (hpdcache_csr->pinned_line_addr_start !=
        ((uintptr_t)buffer >> HPDCACHE_CL_OFFSET_WIDTH)) {
        printf("Error: CSR LINE ADDR START failed test\n");
        ret++;
    }
    if (hpdcache_csr->pinned_line_addr_size != WB_NB_LINES) {
        printf("Error: CSR LINE ADDR SIZE failed test\n");
        ret++;
    }

    printf("Core 0: buffer %p->0x%lx dirtied and pinned\n", buffer,
           ((uintptr_t)buffer) + sizeof(buffer));

    return ret;
}

/* Core 0: leave the cache and the control registers in a state suitable for the
 * next phase of the test */
static void cleanup_pinning() {
    reset_csr();
    for (uint64_t line = 0; line < WB_NB_LINES; line++) {
        flush_cacheline((void *)wb_line(line));
    }
    fence();
}

/* Core 1: wait for the end of the writeback triggered by the pinning of the
 * buffer then check that the region has been written back and is gone from the
 * cache */
static int check_writeback(uint64_t phase) {
    uint64_t mismatches = 0;
    uint64_t polls = 0;
    uint64_t clears = 0;
    int ret = 0;

    /* Core 0 has dirtied the buffer and set the status register, and it
     * activates the pinning of the buffer, which triggers the writeback, now
     * that it knows we are polling that register. The store which modifies the
     * pinned region clears the status: observing that clearing checks that the
     * cache answers requests while the walk which writes the region back is
     * on-going, i.e. that the walk is the lowest priority user of the cache. */
    while (get_writeback_status()) {
        if (++clears > WB_POLL_MAX) {
            printf("Error: HPDCACHE_WRITEBACK_STATUS has never been cleared\n");
            return 1;
        }
    }
    if (clears == 0) {
        printf("Error: HPDCACHE_WRITEBACK_STATUS was never set before the "
               "writeback\n");
        ret++;
    }

    /* Wait for the end of the writeback, counting the requests the cache has
     * answered in the meantime */
    while (!get_writeback_status()) {
        if (++polls > WB_POLL_MAX) {
            printf("Error: HPDCACHE_WRITEBACK_STATUS has never been set\n");
            return 1;
        }
    }
    printf("Core 1: HPDCACHE_WRITEBACK_STATUS is set (after %lu polls)\n",
           polls);

    if (polls == 0) {
        printf("Error: the cache has answered no request during the "
               "writeback\n");
        ret++;
    }

    /* The directory must be inspected before reading the buffer: the reads
     * would allocate the cachelines of the region again */
    mismatches = check_region_cached(0);
    if (mismatches) {
        printf("Error: %lu cachelines of the pinned region are still cached\n",
               mismatches);
        ret++;
    } else {
        printf("Core 1: no cacheline of the pinned region is cached\n");
    }

    /* None of the cachelines of the region is in the cache: reading the buffer
     * reads the memory, which must have received everything core 0 wrote before
     * activating the pinning */
    mismatches = 0;
    for (uint64_t i = 0; i < WB_NB_WORDS; i++) {
        uint64_t expected = wb_pattern(i, phase);
        if (buffer[i] != expected) {
            if (!mismatches) {
                printf("Error: buffer word %lu = 0x%lx, expected 0x%lx\n", i,
                       buffer[i], expected);
            }
            mismatches++;
        }
    }
    if (mismatches) {
        printf("Error: %lu words of the pinned region have not been written "
               "back\n",
               mismatches);
        ret++;
    } else {
        printf("Core 1: whole pinned region written back to memory\n");
    }

    /* The reads have allocated the cachelines of the region again: they must
     * all be cached and pinned now, which checks the way the directory is
     * inspected and that the pinning is active */
    mismatches = check_region_cached(1);
    if (mismatches) {
        printf("Error: %lu cachelines of the pinned region are not cached\n",
               mismatches);
        ret++;
    } else {
        printf("Core 1: whole pinned region cached and pinned again\n");
    }

    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Writeback test region: %p->0x%lx\n", buffer,
               ((uintptr_t)buffer) + sizeof(buffer));

        for (uint64_t phase = 1; phase <= WB_NB_PHASES; phase++) {
            if (phase == 2) {
                printf("Switching to virtualized memory\n");
                build_page_tables();
                csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
                flush_tlb();
            }

            if (dirty_buffer(phase)) {
                printf("Error occured while dirtying the writeback buffer\n");
                exit(-1);
            }
            __sync_store(&stage, 2 * phase - 1);

            /* Trigger the writeback only once core 1 polls the status register,
             * so that its polls overlap the writeback walk */
            if (wait_polling(phase)) {
                exit(-1);
            }
            if (pin_buffer()) {
                printf("Error occured while pinning the writeback buffer\n");
                exit(-1);
            }

            if (wait_stage(2 * phase)) {
                exit(-1);
            }
            cleanup_pinning();
        }

        csr_write(CSR_SATP, 0ul);
        flush_tlb();

        printf("Pinned region writeback behavior correct\n");
    } else {
        for (uint64_t phase = 1; phase <= WB_NB_PHASES; phase++) {
            wait_stage(2 * phase - 1);

            /* Announce that we poll the status register: core 0 triggers the
             * writeback in answer */
            __sync_store(&polling, phase);

            if (check_writeback(phase)) {
                print_cache_state();
                exit(-1);
            }

            __sync_store(&stage, 2 * phase);
        }
    }

    return 0;
}
