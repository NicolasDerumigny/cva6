#include <stdint.h>
#include <stdio.h>

#include "util.h"

#define CACHE_CSR_BASE (0x42 << 16)

typedef struct {
    uint64_t pinned_addr_start;
    uint64_t pinned_addr_size;
} s_hpdcache_csr_t;

int main () {
    if (get_hart_id() == 0) {
        s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t*) CACHE_CSR_BASE;

        hpdcache_csr->pinned_addr_start = 0xfade;
        hpdcache_csr->pinned_addr_size = 0xbeef;

        printf("start=0x%lx size=0x%lx\n", hpdcache_csr->pinned_addr_start, hpdcache_csr->pinned_addr_size);
    }

    return 0;
}
