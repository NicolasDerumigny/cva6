#include <stdio.h>

#include "csr.h"
#include "util.h"
#include "vm.h"

#include "common.h"

uint64_t stage = 0;

int test_pinned_mem_coherency() {
    int ret = 0;
    for (int set = 0; set < 4; set++) {
        table[set << HPDCACHE_CL_OFFSET_WIDTH] = 0xfa;
    }

    init_csr();

    for (int set = 0; set < 4; set++) {
        flush_set(set);
    }
    for (int set = 0; set < 4; set++) {
        if (set % 2) {
            // Pollute one way, value must read to be kept in cache
            // (no-write-allocate in wt mode)
            table_unpinned[set << HPDCACHE_CL_OFFSET_WIDTH] = 0xfa;
            table_unpinned[set << HPDCACHE_CL_OFFSET_WIDTH]++;
        }
    }

    for (int set = 0; set < 4; set++) {
        int way = set % 2;
        int table_idx = set << HPDCACHE_CL_OFFSET_WIDTH;

        table[table_idx] = 0xbe;

        int cached_val = table[table_idx];
        int mem_val_lr = atomic_load_lr((uintptr_t)&table[table_idx]);
        int mem_val_amoadd = atomic_load_amoadd((uintptr_t)&table[table_idx]);
        int cached_val2 = table[table_idx];

        if (cached_val != 0xbe) {
            printf("Error: Cannot read cached value, got 0x%x, expected 0xbe\n",
                   cached_val);
            ret++;
        }
        if (mem_val_amoadd != 0xfa) {
            printf("Error: LR read wrong value, got 0x%x, expected 0xfa\n",
                   mem_val_lr);
            ret++;
        }
        if (mem_val_amoadd != 0xfa) {
            printf("Error: AMOADD read wrong value, got 0x%x, expected 0xfa\n",
                   mem_val_amoadd);
            ret++;
        }
        if (cached_val2 != 0xbe) {
            printf("Error: Pinned value corrupted by LR/AMO, got 0x%x, ",
                   cached_val2);
            printf("expected 0xbe\n");
            ret++;
        }
        if (get_cl_addr(set, way) != (uintptr_t)&table[table_idx]) {
            printf("Error: Wrong CL address set %d way %d, got 0x%lx, expected "
                   "%p\n",
                   set, way, get_cl_addr(set, way), &table[table_idx]);
            ret++;
        }
        if (!get_cl_pinned_state(set, way)) {
            printf("Error: CL set %d way %d was not seen as pinned\n", set,
                   way);
            ret++;
        }
        if (!get_cl_pinned_state(set, way)) {
            printf("Error: CL set %d way %d was not seen as pinned after first "
                   "pinned "
                   "state check\n",
                   set, way);
            ret++;
        }

        flush_cacheline(&table[table_idx]);

        if (get_cl_pinned_state(set, way)) {
            printf("Error: CL set %d way %d was still pinned after flush\n",
                   set, way);
            ret++;
        }

        int val = table[table_idx];

        if (val != 0xbe) {
            printf("Error: Flush has not written back value, got 0x%x, "
                   "expected 0xbe\n",
                   val);
            ret++;
        }
    }

    reset_csr();
    for (int set = 0; set < 4; set++) {
        flush_set(set);
    }

    if (!ret) {
        printf("Pinned/mem coherency + flush ok\n");
    }
    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Test region   (pinned): %p->0x%lx\n", table,
               ((uintptr_t)table) + sizeof(table));
        printf("Test region (unpinned): %p->0x%lx\n", table_unpinned,
               ((uintptr_t)table_unpinned) + sizeof(table_unpinned));

        if (test_pinned_mem_coherency()) {
            printf("Error occured during pinning tests in real address mode\n");
            exit(-1);
        }

        printf("Switching to virtualized memory\n");
        build_page_tables();
        csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
        flush_tlb();

        if (test_pinned_mem_coherency()) {
            printf(
                "Error occured during pinning tests in virtual address mode\n");
            exit(-1);
        }
        csr_write(CSR_SATP, 0ul);
        flush_tlb();
    }

    return 0;
}
