#include <stdio.h>

#include "csr.h"
#include "util.h"
#include "vm.h"

#include "common.h"

uint64_t stage = 0;

int test_pinned_full() {
    int ret = 0;
    // Defautl values
    table_unpinned[0] = 0x42;
    for (int i = 0; i < 3 + (1 << HPDCACHE_WAY_WIDTH); i++) {
        table[i * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))] =
            0x42;
    }
    init_csr();

    // Fill the cache
    for (int i = 0; i < (1 << HPDCACHE_WAY_WIDTH); i++) {
        table[i * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))] =
            0xfa;
    }

    // Check that everything is pinned
    for (int i = 0; i < (1 << HPDCACHE_WAY_WIDTH); i++) {
        if (!get_cl_pinned_state(0, i)) {
            printf("Error: unpinned set on way: %d\n", i);
            ret++;
        }
    }

    // Modification of pinned line on full set, should not hang
    volatile uint8_t *const unpinned_ptr = &table_unpinned[0];
    *unpinned_ptr = 0x43;
    for (int i = 0; i < (1 << HPDCACHE_WAY_WIDTH); i++) {
        if (get_cl_addr(0, i) == (uintptr_t)unpinned_ptr) {
            printf("Error: way %d contains unpinned data\n", i);
            ret++;
        }
    }
    // Access of fully pinned set from a non-pinned region, should not hang
    if (*unpinned_ptr != 0x43) {
        printf("Error: write to unpinned data failed\n");
        ret++;
    }
    *unpinned_ptr = 0;
    printf("Could read/write unpinned data with full set\n");

    //   Launch core 1 unpinning core
    __sync_store(&stage, 1 + __sync_load(&stage));

    // Read req of pinned region with full pinned set. Hangs!
    volatile int8_t val = (int8_t)
        table[8 * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))];
    printf("Core 0 pinned read req was unblocked (val 0x%x)\n", val);

    volatile uint8_t *ptr1 =
        &table[9 * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))];
    volatile uint8_t *ptr2 =
        &table[10 * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))];
    invalidate_cacheline((void *)get_cl_addr(0, 0));
    *ptr1 = 0xff;
    *ptr2 = 0xff;
    printf("Core 0 double write req unblocked\n");

    // Hanging until unblocked by core 1 `flush`
    table[11 * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))] = 0xa0;
    printf("Core 0 write req unblocked\n");

    reset_csr();
    for (int i = 0; i < 5 + (1 << HPDCACHE_WAY_WIDTH); i++) {
        flush_cacheline(
            &table[i * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))]);
        table[i * (1 << (HPDCACHE_SET_WIDTH + HPDCACHE_CL_OFFSET_WIDTH))] = 0;
    }

    if (!ret) {
        printf("Fully pinned behavior correct\n");
    }

    return ret;
}

int unpin_core() {
    int ret = 0;

    // First request is unpinned by `inval`
    while (!set_pinned_full(0)) {
    }
    if (!set_pinned_full(0)) {
        printf("Error: set has switch from full to not full\n");
        ret++;
    }
    // Give time for the core 0 to output its unpinning message if not blocked
    wait();
    printf("Invalidate one pinned cacheline to unblock core 0 (1/3)...\n");
    wait();
    invalidate_cacheline((void *)get_cl_addr(0, 0));

    wait();

    // Again
    while (!set_pinned_full(0)) {
    }
    wait();
    printf("Invalidate one pinned cacheline to unblock core 0 (2/3)...\n");
    wait();
    invalidate_cacheline((void *)get_cl_addr(0, 0));

    // Perform `flush` unpinning for the third req
    while (!set_pinned_full(0)) {
    }
    wait();
    printf("Flushing one pinned cachelines to unblock core 0 (3/3)...\n");
    invalidate_cacheline((void *)get_cl_addr(0, 0));

    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Test region   (pinned): %p->0x%lx\n", table,
               ((uintptr_t)table) + sizeof(table));
        printf("Test region (unpinned): %p->0x%lx\n", table_unpinned,
               ((uintptr_t)table_unpinned) + sizeof(table_unpinned));

        if (test_pinned_full()) {
            printf("Error occured during pinning tests in real address mode\n");
            exit(-1);
        }

        printf("Switching to virtualized memory\n");
        build_page_tables();
        csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
        flush_tlb();

        if (test_pinned_full()) {
            printf(
                "Error occured during pinning tests in virtual address mode\n");
            exit(-1);
        }
        csr_write(CSR_SATP, 0ul);
        flush_tlb();
    } else {
        while (__sync_load(&stage) != 1) {
        }
        if (unpin_core()) {
            print_cache_state();
            return (-1);
        }

        while (__sync_load(&stage) != 2) {
        }
        if (unpin_core()) {
            print_cache_state();
            return (-1);
        }
    }

    return 0;
}
