#include <stdio.h>

#include "utils.h"
#include "types.h"
#include "vm.h"

extern uint64_t _start_text;
extern uint64_t _end_text;
extern uint64_t trampoline_start;
extern uint64_t trampoline_end;

uint64_t *const satp_lvl3 = &__satp_lvl3;
uint64_t *const satp_lvl2 = &__satp_lvl2;
uint64_t *const satp_lvl1 = &__satp_lvl1;
uint64_t *const hgatp_lvl3 = &__hgatp_lvl3;

#define TRAMPOLINE_SIZE ((uint64_t) & trampoline_end - (uint64_t) & trampoline_start)

uint64_t get_aligned_address(uint64_t address, uint size, int level) {
    if (level <= 0 || level > 5) {
        printf("%s : Error (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
        goto error;
    }
    uint64_t aligned = ALIGN_ADDRESS(address, level);
    uint64_t end_address;
    if (__builtin_add_overflow(address, size - 1, &end_address)) {
        printf("%s : Error (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
        goto error;
    }
    if (aligned + ENTRY_MASK_LOWER(level) < end_address) {
        printf("%s : Error (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
        goto error;
    }
    return aligned;

error:
    panic();
    return 0ul;
}

struct segment mapping[MAPPING_MAX];

void build_page_tables(void) {
    for (int i = 0; i < 512; i++) {
        satp_lvl3[i] = 0;
        satp_lvl2[i] = 0;
        satp_lvl1[i] = 0;
        hgatp_lvl3[i] = 0;
        hgatp_lvl3[i + 512] = 0;
        hgatp_lvl3[i + 1024] = 0;
        hgatp_lvl3[i + 1536] = 0;
    }
    // range 0x8000_0000 - 0xcfff_ffff (1-1 mapping for compatibility with baremetal)
    satp_lvl3[0x2] =
        BUILD_PTE(get_aligned_address((uint64_t)&_start_text, (uint64_t)&_end_text - (uint64_t)&_start_text, 3), FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC | DEFAULT_FLAGS);

    // range 0xffff_ffff_c000_0000 - 0xffff_ffff_ffff_ffff (provides lvl2 mapping)
    satp_lvl3[0x1ff] = BUILD_PTE((uint64_t)satp_lvl2, FLAG_VALID);
    // range 0xffff_ffff_ffe0_0000 - 0xffff_ffff_ffff_ffff (provides lvl1 mapping)
    satp_lvl2[0x1ff] = BUILD_PTE((uint64_t)satp_lvl1, FLAG_VALID);

    mapping[MAPPING_LVL3].base = 0xffffffc000000000; // up to 0xffffffc03fffffff
    mapping[MAPPING_LVL3].mask = ENTRY_MASK_LOWER(3);
    mapping[MAPPING_LVL3].associated_pa = get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 3);
    mapping[MAPPING_LVL3].associated_pte = &satp_lvl3[0x100]; // Mapping a 0xffff'ffc0'YXXX'XXXX
    *mapping[MAPPING_LVL3].associated_pte = BUILD_PTE(mapping[MAPPING_LVL3].associated_pa, FLAG_NONE);

    mapping[MAPPING_LVL2].base = 0xffffffffc0000000; // up to 0xffffffffc01fffff
    mapping[MAPPING_LVL2].mask = ENTRY_MASK_LOWER(2);
    mapping[MAPPING_LVL2].associated_pa = get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 2);
    mapping[MAPPING_LVL2].associated_pte = &satp_lvl2[0x0]; // Mapping at 0xffff'ffff'c0YX'XXXX
    *mapping[MAPPING_LVL2].associated_pte = BUILD_PTE(mapping[MAPPING_LVL2].associated_pa, FLAG_NONE);

    mapping[MAPPING_LVL1].base = 0xfffffffffffff000;
    mapping[MAPPING_LVL1].mask = ENTRY_MASK_LOWER(1); // up to 0xffffffffffffffff
    mapping[MAPPING_LVL1].associated_pa = get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 1);
    mapping[MAPPING_LVL1].associated_pte = &satp_lvl1[0x1ff];
    *mapping[MAPPING_LVL1].associated_pte = BUILD_PTE(mapping[MAPPING_LVL1].associated_pa, FLAG_NONE);

    // range 0x8000_0000 - 0xcfff_ffff (1-1 mapping for compatibility with baremetal)
    hgatp_lvl3[2] = BUILD_PTE(get_aligned_address((uint64_t)&_start_text, (uint64_t)&_end_text - (uint64_t)&_start_text, 3),
                                 FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC | FLAG_USER | DEFAULT_FLAGS);
}

uint64_t get_translated_symbol(uint64_t symbol_address, enum mapping id, const char func[], const char file[], int line) {
    struct segment *s = &mapping[id];
    if (symbol_address < s->associated_pa || symbol_address > s->associated_pa + s->mask) {
        printf("%s : Error symbol 0x%lx is not inside segment 0x%lx-0x%lx (mapping %d) (%s:%d)\n",
                func,
                symbol_address,
                s->associated_pa,
                s->associated_pa + s->mask,
                id,
                file,
                line);
        goto error;
    }
    return s->base + (symbol_address & s->mask);

error:
    panic();
    return 0ul;
}
