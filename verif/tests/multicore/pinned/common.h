#include <stdint.h>
#include <stdio.h>

#include "util.h"

#define HPDCACHE_CSR_BASE (0x42 << 20)
#define HPDCACHE_CSR_CL_ADDR (0x1 << 16)
#define HPDCACHE_CSR_CL_PINNED_STATUS (0x2 << 16)
/* Offset, in the configuration segment (0x0), of the read-only status of the
 * pinned region writeback */
#define HPDCACHE_CSR_WRITEBACK_STATUS_OFFSET (0x10)

#define HPDCACHE_CSR_CL_OFFSET_WAY                                             \
    (HPDCACHE_CL_OFFSET_WIDTH + HPDCACHE_SET_WIDTH)
#define fence() asm volatile("fence" ::: "memory")

#define LEN                                                                    \
    (1 << (HPDCACHE_CL_OFFSET_WIDTH + HPDCACHE_WAY_WIDTH +                     \
           HPDCACHE_SET_WIDTH + 1))

#define HPDCACHE_NB_WAYS (1 << HPDCACHE_WAY_WIDTH)
#define HPDCACHE_NB_SETS (1 << HPDCACHE_SET_WIDTH)

typedef struct {
    //  Line address: byte address without the cacheline offset bits
    uint64_t pinned_line_addr_start;
    //  Region length in cachelines
    uint64_t pinned_line_addr_size;
    //  Read-only: set to 1 when the writeback triggered by the last
    //  modification of the pinned region is complete (all the dirty
    //  cachelines of the region have been written back to memory)
    uint64_t writeback_status;
} s_hpdcache_csr_t;

typedef struct {
    union {
        struct {
            uint64_t line : HPDCACHE_CL_OFFSET_WIDTH;
            uint64_t set : HPDCACHE_SET_WIDTH;
            uint64_t tag : HPDCACHE_TAG_WIDTH;
            uint64_t _pad : 64 - HPDCACHE_TAG_WIDTH - HPDCACHE_SET_WIDTH -
                HPDCACHE_CL_OFFSET_WIDTH;
        } __attribute__((packed));
        uint64_t raw;
    } __attribute__((packed));
} __attribute__((packed)) s_hpdcache_csr_tag_t;

static volatile uint8_t table[LEN] __attribute__((aligned(4096)));
static volatile uint8_t table_unpinned[LEN] __attribute__((aligned(4096)));

static void init_csr_region(volatile void *start, uint64_t nlines) {
    fence();
    s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t *)HPDCACHE_CSR_BASE;
    hpdcache_csr->pinned_line_addr_start =
        (uintptr_t)start >> HPDCACHE_CL_OFFSET_WIDTH;
    hpdcache_csr->pinned_line_addr_size = nlines;
    fence();
}

static void init_csr() {
    init_csr_region(table, sizeof(table) >> HPDCACHE_CL_OFFSET_WIDTH);
}

static void reset_csr() {
    fence();
    s_hpdcache_csr_t *hpdcache_csr = (s_hpdcache_csr_t *)HPDCACHE_CSR_BASE;
    hpdcache_csr->pinned_line_addr_start = 0;
    hpdcache_csr->pinned_line_addr_size = 0;
    fence();
}

static inline int atomic_load_amoadd(uintptr_t ptr) {
    int val;
    asm volatile("amoadd.w.aq %0, x0, (%1)" : "=r"(val) : "r"(ptr) : "memory");
    return val;
}

static inline int atomic_load_lr(uintptr_t ptr) {
    int val;
    asm volatile("lr.w %0, (%1)" : "=r"(val) : "r"(ptr) : "memory");
    return val;
}

static inline uintptr_t get_cl_addr(uint64_t set, uint64_t way) {
    void *csr_addr_p = (void *)(HPDCACHE_CSR_BASE + HPDCACHE_CSR_CL_ADDR +
                                (set << HPDCACHE_CL_OFFSET_WIDTH) +
                                (way << HPDCACHE_CSR_CL_OFFSET_WAY));
    s_hpdcache_csr_tag_t csr_addr;
    asm volatile("ld %0, (%1)\n" : "=r"(csr_addr.raw) : "r"(csr_addr_p));
    return csr_addr.raw;
}

static inline int get_cl_pinned_state(uint64_t set, uint64_t way) {
    void *csr_pinned_p =
        (void *)(HPDCACHE_CSR_BASE + HPDCACHE_CSR_CL_PINNED_STATUS +
                 (set << HPDCACHE_CL_OFFSET_WIDTH));
    uint64_t csr_pinned;
    asm volatile("ld %0, (%1)\n" : "=r"(csr_pinned) : "r"(csr_pinned_p));
    return (csr_pinned >> way) & 1;
}

/* Status of the pinned region writeback: 1 when the writeback triggered by the
 * last modification of the pinned region registers is complete */
static inline int get_writeback_status() {
    void *csr_p = (void *)(HPDCACHE_CSR_BASE +
                           HPDCACHE_CSR_WRITEBACK_STATUS_OFFSET);
    uint64_t csr_status;
    asm volatile("ld %0, (%1)\n" : "=r"(csr_status) : "r"(csr_p));
    return csr_status & 1;
}

/* Set of the cache in which a given address is stored */
static inline uint64_t get_set(const volatile void *addr) {
    return ((uintptr_t)addr >> HPDCACHE_CL_OFFSET_WIDTH) &
           (HPDCACHE_NB_SETS - 1);
}

/* Whether the tag of a way is the one of the cacheline containing `addr`.
 * The tag of an invalidated entry is left untouched, so a matching tag does not
 * necessarily mean that the cacheline is still present in the cache */
static inline int cl_tag_is(uint64_t set, uint64_t way,
                            const volatile void *addr) {
    uintptr_t line_addr =
        (uintptr_t)addr & ~(uintptr_t)(HPDCACHE_CACHELINE_SIZE - 1);
    return get_cl_addr(set, way) == line_addr;
}

/* Whether the cacheline containing `addr` is currently stored in the cache.
 * A valid cacheline of the pinned region is always tagged as pinned, either by
 * the writeback controller aligning the directory with the region, or by the
 * allocation path. Therefore, inside the pinned region, a cacheline whose tag
 * matches but which is not pinned is an invalid entry whose tag has been left
 * by a previous invalidation. */
static inline int is_cl_present(uint64_t set, uint64_t way,
                                const volatile void *addr) {
    return cl_tag_is(set, way, addr) && get_cl_pinned_state(set, way);
}

/* Way of `set` whose tag matches the cacheline containing `addr`, -1 if none */
static inline int find_cl_way(uint64_t set, const volatile void *addr) {
    for (uint64_t way = 0; way < HPDCACHE_NB_WAYS; way++) {
        if (cl_tag_is(set, way, addr)) {
            return (int)way;
        }
    }
    return -1;
}

static void print_way_state(uint64_t set) {
    for (uint64_t way = 0; way < (1 << HPDCACHE_WAY_WIDTH); way++) {
        printf("%lu,%lu,", way, set);
        printf("0x%lx,", get_cl_addr(set, way));
        printf("%d;\n", get_cl_pinned_state(set, way));
    }
}

static void print_cache_state() {
    printf("addr,way,set,content,pinned;\n");
    for (uint64_t set = 0; set < 2 /* Keep it small to avoid timeouts */;
         set++) {
        print_way_state(set);
    }
}

static void flush_set(uint64_t set) {
    for (int i = 0; i < 1 << HPDCACHE_WAY_WIDTH; i++) {
        uintptr_t to_flush = get_cl_addr(set, i);
        if (to_flush > 0x80000000 && to_flush < 0x90000000) { // ~is in RAM
            flush_cacheline((void *)to_flush);
        }
    }
}

static void wait() {
    for (int i = 0; i < 500; i++) {
        table_unpinned[i]++;
    }
}

static int set_pinned_full(int set) {
    int ret = 1;
    for (int i = 0; i < 1 << HPDCACHE_WAY_WIDTH; i++) {
        if (!get_cl_pinned_state(set, i)) {
            return 0;
        }
    }
    return 1;
}
