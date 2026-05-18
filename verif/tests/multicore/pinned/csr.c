#include <stdint.h>
#include <stdio.h>

#include "util.h"

#define HPDCACHE_CSR_BASE             (0x42 << 20)
#define HPDCACHE_CSR_CL_ADDR          ( 0x1 << 16)
#define HPDCACHE_CSR_CL_PINNED_STATUS ( 0x2 << 16)

#define HPDCACHE_CL_OFFSET_WIDTH               (4)
#define HPDCACHE_SET_WIDTH                     (8)
#define HPDCACHE_TAG_WIDTH                    (44)
#define HPDCACHE_WAY_WIDTH                     (3)

#define HPDCACHE_CSR_CL_OFFSET_WAY             (HPDCACHE_CL_OFFSET_WIDTH + HPDCACHE_SET_WIDTH)

typedef struct {
    uint64_t pinned_addr_start;
    uint64_t pinned_addr_size;
} s_hpdcache_csr_t;

typedef struct {
    union {
        struct {
            uint64_t line :HPDCACHE_CL_OFFSET_WIDTH;
            uint64_t set  :HPDCACHE_SET_WIDTH;
            uint64_t tag  :HPDCACHE_TAG_WIDTH;
            uint64_t _pad :64-HPDCACHE_TAG_WIDTH-HPDCACHE_SET_WIDTH-HPDCACHE_CL_OFFSET_WIDTH;
        }__attribute__((packed));
        uint64_t raw;
    } __attribute__((packed));
} __attribute__((packed)) s_hpdcache_csr_tag_t;


int main () {
    if (get_hart_id() == 0) {
        s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t*) HPDCACHE_CSR_BASE;

        hpdcache_csr->pinned_addr_start = 0xfade;
        hpdcache_csr->pinned_addr_size = 0xbeef;

        printf("start=0x%lx size=0x%lx\n", hpdcache_csr->pinned_addr_start, hpdcache_csr->pinned_addr_size);

        printf("addr,way,set,content,valid;\n");
        for (uint64_t set = 0; set < 16 /*not too large to avoid timeouts*/; set++) {
            for (uint64_t way = 0; way < (1 << HPDCACHE_WAY_WIDTH); way++) {
                void *csr_addr_p = (void*) (HPDCACHE_CSR_BASE + HPDCACHE_CSR_CL_ADDR + (set << HPDCACHE_CL_OFFSET_WIDTH) + (way << HPDCACHE_CSR_CL_OFFSET_WAY));
                s_hpdcache_csr_tag_t csr_addr;
                asm volatile ("ld %0, (%1)\n":"=r"(csr_addr.raw):"r"(csr_addr_p));

                void *csr_pinned_p = (void*) (HPDCACHE_CSR_BASE + HPDCACHE_CSR_CL_PINNED_STATUS + (set << HPDCACHE_CL_OFFSET_WIDTH));
                uint64_t csr_pinned;
                asm volatile ("ld %0, (%1)\n":"=r"(csr_pinned):"r"(csr_pinned_p));

                printf("%p,", csr_addr_p);
                printf("%lu,%lu,", way, set);
                printf("0x%lx,", csr_addr.raw);
                printf("%lu;\n", (csr_pinned >> way) & 0x1);

            }
        }
    }

    return 0;
}
