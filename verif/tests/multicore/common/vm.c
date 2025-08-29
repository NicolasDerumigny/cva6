#include <stdio.h>

#include "csr.h"
#include "trampoline.h"
#include "types.h"
#include "util.h"
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
uint64_t *const hgatp_lvl3 = &__hgatp_lvl3;
uint64_t *const hgatp_lvl2 = &__hgatp_lvl2;
uint64_t *const hgatp_lvl1 = &__hgatp_lvl1;

const char comment_1GB[] = "1GB";
const char comment_2MB[] = "2MB";
const char comment_4KB[] = "4KB";

struct segment mapping[MAPPING_MAX];

__attribute__((naked, noreturn, aligned(4))) void panic(void) { exit(1); }

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
  return -1;
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

  // range 0xffff_ffff_c000_0000 - 0xffff_ffff_ffff_ffff (provides lvl2 mapping)
  satp_lvl3[0x1ff] = BUILD_PTE((uint64_t)satp_lvl2, FLAG_VALID);
  mapping[MAPPING_S_LVL2].base = 0xffffffffc0000000;
  mapping[MAPPING_S_LVL2].mask =
      ENTRY_MASK_LOWER(2); // up to 0xffffffffc01fffff
  mapping[MAPPING_S_LVL2].associated_pa =
      get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 2);
  mapping[MAPPING_S_LVL2].associated_pte =
      &satp_lvl2[0x0]; // Mapping at 0xffff'ffff'c0YX'XXXX
  *mapping[MAPPING_S_LVL2].associated_pte =
      BUILD_PTE(mapping[MAPPING_S_LVL2].associated_pa, FLAG_NONE);
  mapping[MAPPING_S_LVL2].comment = comment_2MB;

  // range 0xffff_ffff_ffe0_0000 - 0xffff_ffff_ffff_ffff (provides lvl1 mapping)
  satp_lvl2[0x1ff] = BUILD_PTE((uint64_t)satp_lvl1, FLAG_VALID);
  mapping[MAPPING_S_LVL1].base = 0xfffffffffffff000;
  mapping[MAPPING_S_LVL1].mask =
      ENTRY_MASK_LOWER(1); // up to 0xffffffffffffffff
  mapping[MAPPING_S_LVL1].associated_pa =
      get_aligned_address((uint64_t)&trampoline_start, TRAMPOLINE_SIZE, 1);
  mapping[MAPPING_S_LVL1].associated_pte = &satp_lvl1[0x1ff];
  *mapping[MAPPING_S_LVL1].associated_pte =
      BUILD_PTE(mapping[MAPPING_S_LVL1].associated_pa, FLAG_NONE);
  mapping[MAPPING_S_LVL1].comment = comment_4KB;
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
  printf("%s : Panic (%s:%d)\n", __FUNCTION__, __FILE__, __LINE__);
  return -1;
}

__thread struct trap_context *__tc;

__attribute__((naked, aligned(4))) void mvec(void) {
  SAVE_CONTEXT();
  printf("M-mode : panicked (mcause = 0x%lx mepc = 0x%lx mstatus = 0x%lx)\n",
         csr_read(CSR_MCAUSE), csr_read(CSR_MEPC), csr_read(CSR_MSTATUS));
  panic();
}

__attribute__((noreturn, naked, aligned(4))) void panic_vector(void) {
  printf("Panic: ");
  if (csr_read(CSR_SCAUSE) & CAUSE_IRQ_FLAG) {
    switch (csr_read(CSR_SCAUSE) & ~CAUSE_IRQ_FLAG) {
    case 1: {
      printf("Software Interrupt (HS-mode)");
      break;
    }
    case 2: {
      printf("Software Interrupt (VS-mode)");
      break;
    }
    case 3: {
      printf("Software Interrupt (M-mode)");
      break;
    }
    case 5: {
      printf("Timer Interrupt (HS-mode)");
      break;
    }
    case 6: {
      printf("Timer Interrupt (VS-mode)");
      break;
    }
    case 7: {
      printf("Timer Interrupt (M-mode)");
      break;
    }
    case 9: {
      printf("External Interrupt (HS-mode)");
      break;
    }
    case 10: {
      printf("External Interrupt (VS-mode)");
      break;
    }
    case 11: {
      printf("External Interrupt (M-mode)");
      break;
    }
    default: {
      printf("Unsupported Interrupt");
    }
    }
  } else {
    switch (csr_read(CSR_SCAUSE)) {
    case 0: {
      printf("Instruction address misaligned");
      break;
    }
    case 1: {
      printf("Instruction access fault");
      break;
    }
    case 2: {
      printf("Illegal instruction");
      break;
    }
    case 3: {
      printf("Breakpoint");
      break;
    }
    case 4: {
      printf("Load address misaligned");
      break;
    }
    case 5: {
      printf("Load access fault");
      break;
    }
    case 6: {
      printf("Store/AMO address misaligned");
      break;
    }
    case 7: {
      printf("Store/AMO access fault");
      break;
    }
    case 8: {
      printf("Environment call from U-mode or VU-mode");
      break;
    }
    case 9: {
      printf("Environment call from HS-mode");
      break;
    }
    case 10: {
      printf("Environment call from VS-mode");
      break;
    }
    case 11: {
      printf("Environment call from M-mode");
      break;
    }
    case 12: {
      printf("Instruction page fault");
      break;
    }
    case 13: {
      printf("Load page fault");
      break;
    }
    case 15: {
      printf("Store/AMO page fault");
      break;
    }
    case 20: {
      printf("Instruction guest-page fault");
      break;
    }
    case 21: {
      printf("Load guest-page fault");
      break;
    }
    case 22: {
      printf("Virtual instruction");
      break;
    }
    case 23: {
      printf("Store/AMO guest-page fault");
      break;
    }
    default: {
      printf("Unsupported exception");
    }
    }
  }
  printf("\n");
  printf("S-mode : panicked (scause = 0x%lx sepc = 0x%lx stval = 0x%lx)\n",
         csr_read(CSR_SCAUSE), csr_read(CSR_SEPC), csr_read(CSR_STVAL));
  panic();
}

void reset(void) {
  csr_write(CSR_STVEC, &panic_vector);
  csr_write(CSR_SEPC, &panic);
  csr_write(CSR_SIE, 0ul);
  csr_clear(CSR_SSTATUS, SR_SIE);
  csr_write(CSR_HSTATUS, 0ul);
  csr_write(CSR_HIE, 0ul);
  csr_write(CSR_HIDELEG, 0ul);
  csr_write(CSR_HEDELEG, 0ul);
  csr_write(CSR_HCOUNTEREN, 0ul);
  // Activate CBO
  csr_write(CSR_SENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE);
  csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE);
  csr_write(CSR_SATP, 0ul);
  flush_tlb();
}

__thread int hart_id = -1;
void init_hart_id() { hart_id = get_hart_id(); }

void firmware_init(void) {
  init_hart_id();
  csr_write(CSR_MTVEC, (uint64_t)&mvec);
  csr_clear(CSR_MSTATUS, SR_MPP | SR_FS | SR_VS | SR_XS | SR_MPRV);
  csr_set(CSR_MSTATUS, SR_MPP_S | SR_FS_INITIAL | SR_VS_INITIAL |
                           SR_XS_INITIAL); // SR_SXL_64 SR_UXL_64 SR_MPRV
  csr_write(CSR_MENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE);
  csr_write(CSR_MIE, 0ul);
  csr_write(CSR_PMPADDR0, ~0ul);
  csr_write(CSR_MEDELEG,
            bit(EXC_INST_MISALIGNED) | bit(EXC_INST_ACCESS) |
                bit(EXC_INST_ILLEGAL) | bit(EXC_BREAKPOINT) |
                bit(EXC_LOAD_MISALIGNED) | bit(EXC_LOAD_ACCESS) |
                bit(EXC_STORE_MISALIGNED) | bit(EXC_STORE_ACCESS) |
                bit(EXC_U_VU_SYSCALL) | bit(EXC_VS_SYSCALL) |
                bit(EXC_INST_PAGE_FAULT) | bit(EXC_LOAD_PAGE_FAULT) |
                bit(EXC_STORE_PAGE_FAULT) | bit(EXC_INST_GUEST_PAGE_FAULT) |
                bit(EXC_LOAD_GUEST_PAGE_FAULT) | bit(EXC_VIRTUAL_INST_FAULT) |
                bit(EXC_STORE_GUEST_PAGE_FAULT));
  csr_write(CSR_MIDELEG, bit(IRQ_S_SOFT) | bit(IRQ_S_TIMER) | bit(IRQ_S_EXT) |
                             bit(IRQ_S_GEXT) | bit(IRQ_VS_SOFT) |
                             bit(IRQ_VS_TIMER) | bit(IRQ_VS_EXT));
  csr_write(CSR_PMPCFG0, PMP_R | PMP_W | PMP_X | PMP_A_NAPOT);
  reset();

  csr_set(CSR_MIP, bit(IRQ_S_TIMER)); // so the timer interrupt test passes

  asm volatile("la a6, 1f\n"
               "csrw mepc, a6" ::
                   : "memory", "a6");

  asm volatile("mret\n"
               "1:\n");
}

int run_u_mode(int (*f)(void)) {
  firmware_init();
  volatile int ret = 0;
  asm volatile goto("la a6, 1f\n"
                    "csrw stvec, a6" ::
                        : "memory", "a6"
                    : smode_entry_point);
  csr_write(CSR_SEPC, &&umode_entry_point);
  csr_clear(CSR_SSTATUS, SR_SPP | SR_SPIE); // u-mode without interrupts
  asm volatile("sret");

umode_entry_point:
  ret = f();
  //   random ecall
  asm volatile goto("ecall"
                    :
                    :
                    : "memory", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7"
                    : smode_entry_point);

  printf("ERROR: ecall in u-mode returned\n");
  goto end;

smode_entry_point:
  asm volatile(".align 4\n1:");

  uint64_t scause = csr_read(CSR_SCAUSE);
  if (!(scause & CAUSE_IRQ_FLAG)) {
    switch (scause) {
    case EXC_U_VU_SYSCALL: {
      if (!(csr_read(CSR_SSTATUS) & SR_SPP)) {
        return ret;
      }
    }
    }
  }
  printf("ERROR: wrong s-mode signal received (scause=0x%lx)\n", scause);
  panic();
end:
  return -1;
}
