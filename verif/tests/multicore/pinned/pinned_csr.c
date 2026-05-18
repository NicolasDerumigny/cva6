#include <stdio.h>

#include "common.h"

#include "csr.h"
#include "util.h"
#include "vm.h"

uint64_t stage = 0;

int test_csr() {
    s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t *)HPDCACHE_CSR_BASE;
    int ret = 0;

    init_csr();

    if (hpdcache_csr->pinned_addr_start != (uintptr_t)table) {
        printf("Error: CSR ADDR START failed test\n");
        ret++;
    };
    if (hpdcache_csr->pinned_addr_size != sizeof(table)) {
        printf("Error: CSR ADDR SIZE failed test\n");
        ret++;
    };

    reset_csr();

    if (!ret) {
        printf("Basic CSR ok\n");
    }
    return ret;
}

int main() {
    if (get_hart_id() == 0) {
        printf("Test region   (pinned): %p->0x%lx\n", table,
               ((uintptr_t)table) + sizeof(table));
        printf("Test region (unpinned): %p->0x%lx\n", table_unpinned,
               ((uintptr_t)table_unpinned) + sizeof(table_unpinned));

        if (test_csr()) {
            printf("Error occured during pinning tests in real address mode\n");
            exit(-1);
        } else {
        }

        printf("Switching to virtualized memory\n");
        build_page_tables();
        csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
        flush_tlb();

        if (test_csr()) {
            printf(
                "Error occured during pinning tests in virtual address mode\n");
            exit(-1);
        }
        csr_write(CSR_SATP, 0ul);
        flush_tlb();
    }
    return 0;
}
