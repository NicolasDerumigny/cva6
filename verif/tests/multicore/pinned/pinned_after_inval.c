#include <stdio.h>

#include "csr.h"
#include "util.h"
#include "vm.h"

#include "common.h"

uint64_t stage = 0;

int test_pinned_after_inval() {
    int ret = 0;
    flush_set(0);
    table[0] = 0xfa;
    init_csr();
    table[0] = 0xbe;

    invalidate_cacheline(&table[0]);

    int val = table[0];

    if (val != 0xfa) {
        printf("Error: invalidation has failed, got 0x%x, expected 0xfa\n",
               val);
        ret++;
    }

    if (!get_cl_pinned_state(0, 0)) {
        printf(
            "Error: CL set 0 way 0 was unpinned after invalidation + load\n");
        ret++;
    }

    invalidate_cacheline(&table[0]);

    if (get_cl_pinned_state(0, 0)) {
        printf("Error: CL set 0 way 0 was still pinned after invalidation\n");
        ret++;
    }

    reset_csr();
    flush_cacheline(&table[0]);

    if (!ret) {
        printf("Pinned after inval ok\n");
    }

    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Test region   (pinned): %p->0x%lx\n", table,
               ((uintptr_t)table) + sizeof(table));
        printf("Test region (unpinned): %p->0x%lx\n", table_unpinned,
               ((uintptr_t)table_unpinned) + sizeof(table_unpinned));

        if (test_pinned_after_inval()) {
            printf("Error occured during pinning tests in real address mode\n");
            exit(-1);
        }

        printf("Switching to virtualized memory\n");
        build_page_tables();
        csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
        flush_tlb();

        if (test_pinned_after_inval()) {
            printf(
                "Error occured during pinning tests in virtual address mode\n");
            exit(-1);
        }
        csr_write(CSR_SATP, 0ul);
        flush_tlb();
    }

    return 0;
}
