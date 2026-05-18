#include <stdio.h>

#include "types.h"
#include "vm.h"
#define TRAMPOLINE_SIZE                                                        \
  ((uint64_t)&trampoline_end - (uint64_t)&trampoline_start)

extern uint64_t _start_text;
extern uint64_t _end_text;
extern uint64_t trampoline_start;
extern uint64_t trampoline_end;

uint64_t *const satp_lvl3 = &__satp_lvl3;
uint64_t *const satp_lvl2 = &__satp_lvl2;
uint64_t *const satp_lvl1 = &__satp_lvl1;

const char comment_1GB[] = "1GB";
const char comment_2MB[] = "2MB";
const char comment_4KB[] = "4KB";

struct segment mapping[MAPPING_MAX];

uint64_t get_aligned_address(uint64_t address, uint size, int level) {
  if (level <= 0 || level > 5) {
    printf("%s : Error level (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
    goto error;
  }
  uint64_t aligned = ALIGN_ADDRESS(address, level);
  uint64_t end_address;
  if (__builtin_add_overflow(address, size - 1, &end_address)) {
    printf("%s : Error overflow (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
    goto error;
  }
  if (aligned + ENTRY_MASK_LOWER(level) < end_address) {
    printf("%s : Error end address (%s:%d)\n", __FUNCTION__, __FILE__,
           __LINE__);
    goto error;
  }
  return aligned;

error:
  return 0ul;
}

void build_page_tables(void) {
  for (int i = 0; i < 512; i++) {
    satp_lvl3[i] = 0;
    satp_lvl2[i] = 0;
    satp_lvl1[i] = 0;
  }
  // range 0x8000_0000 - 0xcfff_ffff (1-1 mapping for compatibility with
  // baremetal)
  satp_lvl3[0x2] = BUILD_PTE(
      get_aligned_address((uint64_t)&_start_text,
                          (uint64_t)&_end_text - (uint64_t)&_start_text, 3),
      FLAG_VALID | FLAG_READ | FLAG_WRITE | FLAG_EXEC | DEFAULT_FLAGS);
  mapping[MAPPING_S_LVL3].base = 0xffffffc000000000;
  mapping[MAPPING_S_LVL3].mask =
      ENTRY_MASK_LOWER(3); // up to 0xffffffc03fffffff
  mapping[MAPPING_S_LVL3].associated_pa =
      get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 3);
  mapping[MAPPING_S_LVL3].associated_pte =
      &satp_lvl3[0x100]; // Mapping a 0xffff'ffc0'YXXX'XXXX
  *mapping[MAPPING_S_LVL3].associated_pte =
      BUILD_PTE(mapping[MAPPING_S_LVL3].associated_pa, FLAG_NONE);
  mapping[MAPPING_S_LVL3].comment = comment_1GB;
}

uint64_t get_translated_symbol(uint64_t symbol_address, enum mapping id,
                               const char func[], const char file[], int line) {
  struct segment *s = &mapping[id];
  if (symbol_address < s->associated_pa ||
      symbol_address > s->associated_pa + s->mask) {
    printf("%s : Error symbol 0x%lx is not inside segment 0x%lx-0x%lx (mapping "
           "%d) (%s:%d)\n",
           func, symbol_address, s->associated_pa, s->associated_pa + s->mask,
           id, file, line);
    goto error;
  }
  return s->base + (symbol_address & s->mask);

error:
  return 0ul;
}
