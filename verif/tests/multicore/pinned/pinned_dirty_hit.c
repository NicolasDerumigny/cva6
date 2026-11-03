/*
 * Test of a pinned store hitting a cacheline which is dirty and not pinned yet.
 *
 * Core 0 writes a buffer, leaving all its cachelines dirty in the cache with a
 * value the memory does not have, then activates the pinning of that buffer:
 * this writes back the dirty cachelines which should have been pinned. Before
 * the writeback walk reaches a cacheline, core 0 stores a new value into it.
 * That store must not overwrite a value the memory has not received yet: the
 * flush controller writes the old value back first, and the store lands in the
 * cacheline afterwards, which stays present, dirty and pinned.
 *
 * The stored cachelines are the ones of the last sets of the cache, and the
 * stores are made as soon as the region is written: the walk goes through the
 * sets in increasing order, so it is still writing back the cachelines of the
 * other sets when the stores arrive. The cachelines the stores do not touch are
 * written back and invalidated by the walk, so reading them back reads the
 * memory, which must give what core 0 wrote before the activation.
 *
 * A pinned cacheline is never evicted nor written back, so a load cannot see
 * the memory it hides. An AMO hitting a pinned cacheline is sent uncached
 * instead: core 1 uses that to check that the memory holds the old value of
 * the stored cachelines while the cache holds the new one, which is the only
 * way to see that they are still dirty.
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

/* Cachelines of the buffer: two per set, so that the last sets of the cache
 * hold a stored cacheline and a cacheline the stores leave alone */
#define DH_LINES_PER_SET (2)
#define DH_NB_LINES (HPDCACHE_NB_SETS * DH_LINES_PER_SET)
#define DH_WORDS_PER_LINE (HPDCACHE_CACHELINE_SIZE / 8)
#define DH_NB_WORDS (DH_NB_LINES * DH_WORDS_PER_LINE)

/* The stored cachelines are the last lines of the region: they are the ones the
 * walk of the directory reaches last, since it goes through the sets of the
 * cache in increasing order */
#define DH_NB_TARGETS (4)
#define DH_TARGET_LINE (DH_NB_LINES - DH_NB_TARGETS)
#define DH_TARGET_FIRST_SET (HPDCACHE_NB_SETS - DH_NB_TARGETS)

/* Word of the stored cachelines the store overwrites: the other words of the
 * cacheline keep the value dirtied before the activation */
#define DH_STORED_WORD (4)

static volatile uint64_t buffer[DH_NB_WORDS] __attribute__((aligned(4096)));

/* The test is run in real address mode then in virtual address mode */
#define DH_NB_PHASES (2)

/* Maximum number of polls before declaring the writeback stalled: the walk
 * lasts three cycles per directory entry, and it yields the cache directory
 * to the requests waiting for the cache pipeline, plus the time to write the
 * region back to memory */
#define DH_POLL_MAX (100000)

/* Maximum number of iterations of the handshakes between the two cores: one
 * core must not wait forever for the other one if it has given up */
#define DH_SYNC_MAX (1000000)

/* Which of the three values a buffer word takes during the test */
#define DH_BASE (0)
#define DH_OLD (1)
#define DH_NEW (2)

/* Content of a buffer word of index `word`: each phase checks a different
 * pattern, so a match cannot come from a previous phase */
static uint64_t dh_word(uint64_t word, uint64_t phase, uint64_t kind) {
    return (word * 0x9e3779b97f4a7c15UL) ^
           ((phase * 3 + kind) * 0xd1342543de82ef95UL);
}

/* Handshake between the cores on the stage they have reached: bounded so that a
 * core which gives up does not make the other one wait until the timeout */
static int wait_stage(uint64_t expected) {
    uint64_t polls = 0;

    while (__sync_load(&stage) != expected) {
        if (++polls > DH_SYNC_MAX) {
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
        if (++polls > DH_SYNC_MAX) {
            printf("Error: timeout waiting for core 1 to poll the status\n");
            return 1;
        }
    }

    return 0;
}

static volatile void *dh_line(uint64_t line) {
    return (volatile void *)&buffer[line * DH_WORDS_PER_LINE];
}

/* Whether core 0 stores into the cacheline of that buffer line */
static int dh_is_target(uint64_t line) {
    return line >= DH_TARGET_LINE;
}

/* Whether that buffer line is one of the cachelines of the last sets of the
 * cache, the ones the walk of the directory reaches last */
static int dh_is_late(uint64_t line) {
    return get_set(dh_line(line)) >= DH_TARGET_FIRST_SET;
}

/* Ways of `set` whose tag is tagged as pinned. Inside the pinned region a
 * present cacheline is always tagged as pinned, either by the allocation path
 * or by the writeback walk aligning the directory with the registers, so no
 * other way can hold a cacheline of the region */
static uint64_t dh_pinned_ways(uint64_t set) {
    void *csr_p = (void *)(HPDCACHE_CSR_BASE + HPDCACHE_CSR_CL_PINNED_STATUS +
                           (set << HPDCACHE_CL_OFFSET_WIDTH));
    uint64_t csr_pinned;

    asm volatile("ld %0, (%1)\n" : "=r"(csr_pinned) : "r"(csr_p));

    return csr_pinned;
}

/* Whether the cacheline containing `addr` is present in the cache. Only the
 * ways tagged as pinned of its set are looked at, which is how much of the
 * register accesses the check of a whole region costs */
static int dh_is_present(const volatile void *addr) {
    uint64_t set = get_set(addr);
    uint64_t pinned_ways = dh_pinned_ways(set);

    for (uint64_t way = 0; way < HPDCACHE_NB_WAYS; way++) {
        if (((pinned_ways >> way) & 1) && cl_tag_is(set, way, addr)) {
            return 1;
        }
    }

    return 0;
}

/* Read a word of the buffer in the memory: an AMO hitting a pinned cacheline
 * is sent uncached, which is the only way to look at the memory of a cacheline
 * which is present and dirty in the cache */
static uint32_t dh_memory_word(uint64_t word) {
    return (uint32_t)atomic_load_amoadd((uintptr_t)&buffer[word]);
}

/* Core 0: leave every cacheline of the buffer present and dirty in the cache,
 * with a value the memory does not have and none of them pinned, then set the
 * status register, the only event which clears it afterwards being the
 * activation of the pinning under test. Returns 1 on failure */
static int dirty_buffer(uint64_t phase) {
    uint64_t sum = 0;
    uint64_t polls = 0;
    int ret = 0;

    /* Start from a clean state: no cacheline of the buffer in the cache, and
     * the memory of the stored cachelines holding a value which is neither the
     * one the stores dirty them with nor the one the walk writes back */
    reset_csr();

    for (uint64_t line = DH_TARGET_LINE; line < DH_NB_LINES; line++) {
        volatile uint64_t *words = (volatile uint64_t *)dh_line(line);

        for (uint64_t w = 0; w < DH_WORDS_PER_LINE; w++) {
            words[w] = dh_word(line * DH_WORDS_PER_LINE + w, phase, DH_BASE);
        }
        fence();
        /* Only a flush CMO gets rid of a cacheline of the region: it writes it
         * back, then invalidates it and clears its pinned tag */
        flush_cacheline((void *)dh_line(line));
    }
    fence();

    /* Dirty every cacheline of the buffer: the region is not pinned yet, so
     * none of them is pinned, and the memory keeps its previous value */
    for (uint64_t i = 0; i < DH_NB_WORDS; i++) {
        buffer[i] = dh_word(i, phase, DH_OLD);
    }
    fence();

    /* Make sure the stores have reached the cache before modifying the pinned
     * region: they are the data which must be written back */
    for (uint64_t i = 0; i < DH_NB_WORDS; i++) {
        sum += buffer[i];
    }
    if (sum == 0) {
        printf("Error: buffer has not been filled\n");
        ret++;
    }
    fence();

    /* Every cacheline of the buffer must be present in the cache: they are what
     * the walk has to write back. The two cachelines of a set are looked for
     * at once, so that the tag of a way is read only once. The region is not
     * pinned yet, so only the tags are meaningful */
    for (uint64_t set = 0; set < HPDCACHE_NB_SETS; set++) {
        uintptr_t addrs[DH_LINES_PER_SET];
        int found[DH_LINES_PER_SET];
        uint64_t missing = 0;

        for (uint64_t i = 0; i < DH_LINES_PER_SET; i++) {
            addrs[i] = (uintptr_t)dh_line(set + i * HPDCACHE_NB_SETS);
            addrs[i] &= ~(uintptr_t)(HPDCACHE_CACHELINE_SIZE - 1);
            found[i] = 0;
        }

        for (uint64_t way = 0; way < HPDCACHE_NB_WAYS; way++) {
            uintptr_t tag = get_cl_addr(set, way);

            for (uint64_t i = 0; i < DH_LINES_PER_SET; i++) {
                if (tag == addrs[i]) {
                    found[i] = 1;
                }
            }
        }

        for (uint64_t i = 0; i < DH_LINES_PER_SET; i++) {
            if (!found[i]) {
                printf("Error: cacheline %p of the buffer is not cached\n",
                       dh_line(set + i * HPDCACHE_NB_SETS));
                missing++;
            }
        }
        ret += (missing != 0);
    }

    /* Write back an empty region, which only sets the status register */
    init_csr_region(buffer, 0);
    while (!get_writeback_status()) {
        if (++polls > DH_POLL_MAX) {
            printf("Error: HPDCACHE_WRITEBACK_STATUS has never been set by the "
                   "writeback of the empty region\n");
            return 1;
        }
    }

    return ret;
}

/* Core 0: activate the pinning of the buffer, which starts the walk writing
 * back the dirty cachelines of the region, then store a new value in the
 * cachelines the walk reaches last, without any register access in between: the
 * walk is still busy with the cachelines of the other sets, so it finds those
 * cachelines already pinned */
static int activate_and_store(uint64_t phase) {
    s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t *)HPDCACHE_CSR_BASE;
    uint64_t new[DH_NB_TARGETS];
    int ret = 0;

    /* The values are computed before the region is written: nothing but the
     * stores must separate the activation of the pinning from the stores */
    for (uint64_t i = 0; i < DH_NB_TARGETS; i++) {
        uint64_t word = (DH_TARGET_LINE + i) * DH_WORDS_PER_LINE;

        new[i] = dh_word(word + DH_STORED_WORD, phase, DH_NEW);
    }

    init_csr_region(buffer, DH_NB_LINES);

    for (uint64_t i = 0; i < DH_NB_TARGETS; i++) {
        volatile uint64_t *word =
            (volatile uint64_t *)dh_line(DH_TARGET_LINE + i) + DH_STORED_WORD;

        *word = new[i];
    }

    if (hpdcache_csr->pinned_line_addr_start !=
        ((uintptr_t)buffer >> HPDCACHE_CL_OFFSET_WIDTH)) {
        printf("Error: CSR LINE ADDR START failed test\n");
        ret++;
    }
    if (hpdcache_csr->pinned_line_addr_size != DH_NB_LINES) {
        printf("Error: CSR LINE ADDR SIZE failed test\n");
        ret++;
    }

    for (uint64_t i = 0; i < DH_NB_TARGETS; i++) {
        volatile uint64_t *word =
            (volatile uint64_t *)dh_line(DH_TARGET_LINE + i) + DH_STORED_WORD;
        uint64_t polls = 0;

        /* The store waits for the writeback of the value it overwrites before
         * being performed: wait until it is visible in the cache, so that core
         * 1 does not check a store which has not been made yet */
        while (*word != new[i]) {
            if (++polls > DH_POLL_MAX) {
                printf("Error: store to cacheline %p has not been made\n",
                       dh_line(DH_TARGET_LINE + i));
                return 1;
            }
        }
    }
    fence();

    printf("Core 0: buffer %p->0x%lx dirtied, pinned, then stored into\n",
           buffer, ((uintptr_t)buffer) + sizeof(buffer));

    return ret;
}

/* Core 0: leave the cache and the control registers in a state suitable for the
 * next phase of the test */
static void cleanup_pinning() {
    reset_csr();
    for (uint64_t line = 0; line < DH_NB_LINES; line++) {
        flush_cacheline((void *)dh_line(line));
    }
    fence();
}

/* Core 1: check the cachelines core 0 stored into. They must still be present
 * and pinned, the cache must hold the new value of the stored word and the old
 * value of the other ones, and the memory must hold the old value of every
 * word: it is what the store made the flush controller write back, and the
 * difference with the cache is what shows the cacheline is still dirty */
static int check_stored_lines(uint64_t phase) {
    uint64_t errors = 0;

    for (uint64_t line = DH_TARGET_LINE; line < DH_NB_LINES; line++) {
        volatile void *addr = dh_line(line);
        uint64_t base = line * DH_WORDS_PER_LINE;

        if (!dh_is_present(addr)) {
            printf("Error: stored cacheline %p is not cached and pinned\n",
                   addr);
            errors++;
            continue;
        }

        for (uint64_t w = 0; w < DH_WORDS_PER_LINE; w++) {
            uint64_t i = base + w;
            uint64_t expected = dh_word(i, phase, DH_OLD);
            uint64_t new = dh_word(i, phase, DH_NEW);
            int stored = (w == DH_STORED_WORD);
            uint32_t in_memory;

            /* The store is merged into the cacheline: the word it overwrites
             * holds the new value and the other ones are left untouched */
            if (buffer[i] != (stored ? new : expected)) {
                printf("Error: cacheline %p word %lu = 0x%lx in the cache, "
                       "expected 0x%lx\n", addr, w, buffer[i],
                       stored ? new : expected);
                errors++;
            }

            /* The memory holds what the flush controller wrote back before the
             * store. The word the store overwrites may have been read by the
             * controller afterwards, so both values are accepted there */
            in_memory = dh_memory_word(i);
            if (in_memory != (uint32_t)expected &&
                !(stored && in_memory == (uint32_t)new)) {
                printf("Error: cacheline %p word %lu = 0x%x in the memory, "
                       "expected 0x%x\n", addr, w, in_memory,
                       (uint32_t)expected);
                errors++;
            }
        }
    }

    if (errors) {
        printf("Error: %lu problems with the stored cachelines\n", errors);
        return 1;
    }

    printf("Core 1: %lu pinned stores wrote the old value back and stayed "
           "dirty and pinned\n", (unsigned long)DH_NB_TARGETS);

    return 0;
}

/* Core 1: check that every cacheline of the region the stores did not touch has
 * been written back to the memory and invalidated, and that reading the region
 * back caches and pins all of it again. Only the cachelines of the last sets,
 * which the walk reaches last, are read word by word: the others are read at
 * both ends, and pinned_writeback.c reads a whole region word by word */
static int check_written_back_lines(uint64_t phase) {
    uint64_t errors = 0;
    uint64_t mismatches = 0;
    uint64_t kept = 0;

    /* The directory must be inspected before reading the buffer: the reads
     * would allocate the cachelines of the region again */
    for (uint64_t line = 0; line < DH_NB_LINES; line++) {
        volatile void *addr = dh_line(line);
        uint64_t base = line * DH_WORDS_PER_LINE;

        if (dh_is_target(line) || !dh_is_present(addr)) {
            continue;
        }

        /* The walk writes back and invalidates the cachelines which are dirty.
         * A cacheline dirtied before the activation, then evicted and read back
         * before the walk reaches it, is clean: the walk pins it and leaves it
         * in the cache, where it cannot be evicted anymore. What the walk must
         * not leave behind is a cacheline dirtier than its memory */
        for (uint64_t w = 0; w < DH_WORDS_PER_LINE; w++) {
            if ((uint32_t)buffer[base + w] != dh_memory_word(base + w)) {
                printf("Error: cacheline %p of the pinned region is still "
                       "cached and dirty\n", addr);
                errors++;
                break;
            }
        }
        kept++;
    }

    /* None of these cachelines is in the cache anymore: reading them reads the
     * memory, which must have received everything core 0 wrote there before
     * activating the pinning */
    for (uint64_t line = 0; line < DH_NB_LINES; line++) {
        if (dh_is_target(line)) {
            continue;
        }
        for (uint64_t w = 0; w < DH_WORDS_PER_LINE; w++) {
            uint64_t i = line * DH_WORDS_PER_LINE + w;

            /* The cachelines of the last sets, the ones the walk reaches last,
             * are read word by word; the others are read at both ends */
            if (!dh_is_late(line) && w != 0 && w != DH_WORDS_PER_LINE - 1) {
                continue;
            }
            if (buffer[i] != dh_word(i, phase, DH_OLD)) {
                if (!mismatches) {
                    printf("Error: buffer word %lu = 0x%lx, expected "
                           "0x%lx\n", i, buffer[i], dh_word(i, phase, DH_OLD));
                }
                mismatches++;
            }
        }
    }
    if (mismatches) {
        printf("Error: %lu words of the pinned region have not been written "
               "back\n", mismatches);
        errors++;
    }

    /* The reads have allocated the cachelines of the region again: all of them
     * must be cached and pinned now, which checks the way the directory is
     * inspected above and that the pinning is active */
    for (uint64_t line = 0; line < DH_NB_LINES; line++) {
        volatile void *addr = dh_line(line);

        if (!dh_is_present(addr)) {
            printf("Error: cacheline %p of the pinned region is not cached\n",
                   addr);
            errors++;
        }
    }

    if (errors) {
        return 1;
    }

    printf("Core 1: pinned region written back, cached and pinned again "
           "(%lu clean cachelines left pinned)\n",
           (unsigned long)kept);

    return 0;
}

/* Core 1: wait for the end of the writeback triggered by the pinning of the
 * buffer, then check the result of the stores core 0 made during it */
static int check_writeback(uint64_t phase) {
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
        if (++clears > DH_POLL_MAX) {
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
        if (++polls > DH_POLL_MAX) {
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

    if (check_stored_lines(phase)) {
        ret++;
    }

    if (check_written_back_lines(phase)) {
        ret++;
    }

    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Dirty hit test region: %p->0x%lx\n", buffer,
               ((uintptr_t)buffer) + sizeof(buffer));

        for (uint64_t phase = 1; phase <= DH_NB_PHASES; phase++) {
            if (phase == 2) {
                printf("Switching to virtualized memory\n");
                build_page_tables();
                csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
                flush_tlb();
            }

            if (dirty_buffer(phase)) {
                printf("Error occured while dirtying the buffer\n");
                exit(-1);
            }
            __sync_store(&stage, 2 * phase - 1);

            /* Trigger the writeback only once core 1 polls the status register,
             * so that its polls overlap the writeback walk */
            if (wait_polling(phase)) {
                exit(-1);
            }
            if (activate_and_store(phase)) {
                printf("Error occured while pinning and storing the buffer\n");
                exit(-1);
            }

            if (wait_stage(2 * phase)) {
                exit(-1);
            }
            cleanup_pinning();
        }

        csr_write(CSR_SATP, 0ul);
        flush_tlb();

        printf("Pinned store on a dirty cacheline behavior correct\n");
    } else {
        for (uint64_t phase = 1; phase <= DH_NB_PHASES; phase++) {
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
