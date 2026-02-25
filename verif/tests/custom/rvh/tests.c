#include <stdio.h>

#include "call.h"
#include "csr.h"
#include "sbi.h"
#include "tests.h"
#include "trampoline.h"
#include "types.h"
#include "utils.h"
#include "vm.h"

void notice_success(void) {
    printf("Succeeded\n");
}

void notice_failure(void) {
    printf("Failed\n");
}

void notice_failure_detailed(char *msg) {
    printf("Failed (%s)\n", msg);
}

void test_timer(void) {
    printf("Starting test: HS-mode (timer interrupt)\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : entry_point);
    csr_set(CSR_SIE, IE_S_TIE); // enable timer interrupts
    csr_set(CSR_SSTATUS, SR_SIE); // enable interrupts (general switch)
    asm volatile("wfi");
    notice_failure();
    goto end;

entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (scause & CAUSE_IRQ_FLAG) {
        switch (scause & ~CAUSE_IRQ_FLAG) {
            case IRQ_S_TIMER: { // optionally you can give a second chance in case another interrupt is caught
                notice_success();
                goto end;
            }
        }
    }
    printf("\tFailed (wrong signal received)\n");

end:
    return;
}

void test_u_mode(void) {
    printf("Starting test: U-mode (ecall) \n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : smode_entry_point);
    csr_write(CSR_SEPC, &&umode_entry_point);
    csr_clear(CSR_SSTATUS, SR_SPP | SR_SPIE); // u-mode without interrupts
    asm volatile("sret");

umode_entry_point:
    // random ecall
    asm volatile goto("ecall" : : : "memory", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7" : smode_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

smode_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_U_VU_SYSCALL: {
                if (!(csr_read(CSR_SSTATUS) & SR_SPP)) {
                    notice_success();
                    goto end;
                }
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_vs_mode_1(void) {
    printf("Starting test: VS mode (ecall) - no G/S translation\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSATP, 0ul); // vs page table
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG, 0ul); // hypervisor exception delegation
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_HGATP, 0ul); // nested page table
    flush_htlb();

    csr_write(CSR_SEPC, &&guest_entry_point);
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode

    asm volatile("sret");

guest_entry_point:
    register uint64_t a7 asm("a7") = SBI_EXT_BASE;
    register uint64_t a6 asm("a6") = SBI_EXT_BASE_GET_SPEC_VERSION;
    asm volatile goto("ecall" : : "r"(a6), "r"(a7) : "memory", "a0", "a1", "a2", "a3", "a4", "a5" : host_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

host_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_VS_SYSCALL: {
                uint64_t hstatus = csr_read(CSR_HSTATUS);
                if ((hstatus & (HSTATUS_SPV | HSTATUS_SPVP)) == (HSTATUS_SPV | HSTATUS_SPVP)) {
                    notice_success();
                } else {
                    notice_failure(); // wrong hstatus
                }
                goto end;
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_vs_mode_2(void) {
    printf("Starting test: VS mode (ecall) - only G translation (no U flag)\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSATP, 0ul); // vs page table
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG, 0ul); // hypervisor exception delegation
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_HGATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39)); // nested page table
    flush_htlb();

    csr_write(CSR_SEPC, &&guest_entry_point);
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration

    asm volatile("sret");

guest_entry_point:
    register uint64_t a7 asm("a7") = SBI_EXT_BASE;
    register uint64_t a6 asm("a6") = SBI_EXT_BASE_GET_SPEC_VERSION;
    asm volatile goto("ecall" : : "r"(a6), "r"(a7) : "memory", "a0", "a1", "a2", "a3", "a4", "a5" : host_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

host_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_VS_SYSCALL: {
                notice_failure(); // wrong hstatus
                goto end;
            }
            case EXC_INST_GUEST_PAGE_FAULT: {
                uint64_t hstatus = csr_read(CSR_HSTATUS);
                if ((hstatus & (HSTATUS_SPV | HSTATUS_SPVP)) == (HSTATUS_SPV | HSTATUS_SPVP)) {
                    notice_success();
                } else {
                    notice_failure(); // wrong hstatus
                }
                goto end;
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_vs_mode_3(void) {
    printf("Starting test: VS mode (ecall) - only G translation (valid)\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSATP, 0ul); // vs page table
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG, 0ul); // hypervisor exception delegation
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_HGATP, MAKE_SATP(HGATP_ROOT, SATP_MODE_39)); // nested page table
    flush_htlb();

    csr_write(CSR_SEPC, &&guest_entry_point);
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration

    asm volatile("sret");

guest_entry_point:
    register uint64_t a7 asm("a7") = SBI_EXT_BASE;
    register uint64_t a6 asm("a6") = SBI_EXT_BASE_GET_SPEC_VERSION;
    asm volatile goto("ecall" : : "r"(a6), "r"(a7) : "memory", "a0", "a1", "a2", "a3", "a4", "a5" : host_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

host_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_VS_SYSCALL: {
                uint64_t hstatus = csr_read(CSR_HSTATUS);
                if ((hstatus & (HSTATUS_SPV | HSTATUS_SPVP)) == (HSTATUS_SPV | HSTATUS_SPVP)) {
                    notice_success();
                } else {
                    notice_failure(); // wrong hstatus
                }
                goto end;
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_vs_mode_4(void) {
    printf("Starting test: VS mode (ecall) - only S translation\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG, 0ul); // hypervisor exception delegation
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, 0ul); // hypervisor environment controls
    csr_write(CSR_HGATP, 0ul); // nested page table
    flush_htlb();
    csr_write(CSR_VSATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39)); // vs page table
    flush_vtlb();

    csr_write(CSR_SEPC, &&guest_entry_point);
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration

    asm volatile("sret");

guest_entry_point:
    register uint64_t a7 asm("a7") = SBI_EXT_BASE;
    register uint64_t a6 asm("a6") = SBI_EXT_BASE_GET_SPEC_VERSION;
    asm volatile goto("ecall" : : "r"(a6), "r"(a7) : "memory", "a0", "a1", "a2", "a3", "a4", "a5" : host_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

host_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_VS_SYSCALL: {
                uint64_t hstatus = csr_read(CSR_HSTATUS);
                if ((hstatus & (HSTATUS_SPV | HSTATUS_SPVP)) == (HSTATUS_SPV | HSTATUS_SPVP)) {
                    notice_success();
                } else {
                    notice_failure(); // wrong hstatus
                }
                goto end;
            }
            case EXC_INST_PAGE_FAULT: {
                notice_failure_detailed("instruction fault");
                goto end;
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_vs_mode_5(void) {
    printf("Starting test: VS mode (ecall) - both G/S translations\n");

    printf("\t- Run: ");
    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG, 0ul); // hypervisor exception delegation
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_HGATP, MAKE_SATP(HGATP_ROOT, SATP_MODE_39)); // nested page table
    flush_htlb();
    csr_write(CSR_VSATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39)); // vs page table
    flush_vtlb();

    csr_write(CSR_SEPC, &&guest_entry_point);
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration

    asm volatile("sret");

guest_entry_point:
    register uint64_t a7 asm("a7") = SBI_EXT_BASE;
    register uint64_t a6 asm("a6") = SBI_EXT_BASE_GET_SPEC_VERSION;
    asm volatile goto("ecall" : : "r"(a6), "r"(a7) : "memory", "a0", "a1", "a2", "a3", "a4", "a5" : host_entry_point);

    notice_failure_detailed("ecall returned");
    goto end;

host_entry_point:
    asm volatile(".align 4\n1:");
    uint64_t scause = csr_read(CSR_SCAUSE);
    if (!(scause & CAUSE_IRQ_FLAG)) {
        switch (scause) {
            case EXC_VS_SYSCALL: {
                uint64_t hstatus = csr_read(CSR_HSTATUS);
                if ((hstatus & (HSTATUS_SPV | HSTATUS_SPVP)) == (HSTATUS_SPV | HSTATUS_SPVP)) {
                    notice_success();
                } else {
                    notice_failure(); // wrong hstatus
                }
                goto end;
            }
            case EXC_INST_PAGE_FAULT: {
                notice_failure_detailed("instruction fault");
                goto end;
            }
        }
    }
    notice_failure_detailed("wrong signal received");

end:
    return;
}

void test_satp_noread(enum mapping mapping_type) {
    asm volatile("ld a5, 0(%0)\n"
                 "call notice_failure\n"
                 ::"r"(get_translated_symbol((uint64_t)&flag, mapping_type, __FUNCTION__, __FILE__, __LINE__))
                 : "memory", "a5");
}

void test_satp_nowrite(enum mapping mapping_type) {
    __sync_store(&flag, 42);
    asm volatile("sd %0, 0(%1)\n"
                 "call notice_failure\n"
                 ::"r"(0),
                 "r"(get_translated_symbol((uint64_t)&flag, mapping_type, __FUNCTION__, __FILE__, __LINE__))
                 : "memory");
}

void test_satp_noexec(enum mapping mapping_type) {
    asm volatile("jalr %0\n"
                 "call notice_failure\n"
                 ::"r"(get_translated_symbol((uint64_t)&test_ret, mapping_type, __FUNCTION__, __FILE__, __LINE__))
                 : "memory", "ra");
}

void test_satp_read(enum mapping mapping_type) {
    uint64_t* symb_addr = (uint64_t*) get_translated_symbol((uint64_t)&flag, mapping_type, __FUNCTION__, __FILE__, __LINE__);
    __sync_store(&flag, 0xabacadaba);
    uint64_t test_flag = __sync_load(symb_addr);
    // Failure is notified in interrupt handler
    if (test_flag == 0xabacadaba) {
        notice_success();
    }
}

void test_satp_write(enum mapping mapping_type) {
    __sync_store(&flag, 0);
    __sync_store((uint64_t *)get_translated_symbol((uint64_t)&flag, mapping_type, __FUNCTION__, __FILE__, __LINE__), 451);
    // Failure is notified in interrupt handler
    if (__sync_load(&flag) == 451) {
        notice_success();
    }
}

void test_satp_exec(enum mapping mapping_type) {
    asm volatile("jalr ra,0(%0)\n"
                 "call notice_success" ::"r"(get_translated_symbol((uint64_t)&test_ret, mapping_type, __FUNCTION__, __FILE__, __LINE__))
                 : "memory");
}

__attribute__((naked, aligned(4))) void noread_entry_point(void) {
    SAVE_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_LOAD_GUEST_PAGE_FAULT:
        case EXC_LOAD_PAGE_FAULT: {
            notice_success();
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 2));
            break;
        }
        case EXC_STORE_GUEST_PAGE_FAULT:
        case EXC_STORE_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected store page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            notice_failure();
            printf("Unexepected interrupt at 0x%lx: 0x%lx\n", csr_read(CSR_SEPC), scause);
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

__attribute__((naked, aligned(4))) void nowrite_entry_point(void) {
    SAVE_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_STORE_GUEST_PAGE_FAULT:
        case EXC_STORE_PAGE_FAULT: {
            if (__sync_load(&flag) != 0) {
                notice_success();
                csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 2));
            } else {
                csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            }
            break;
        }
        case EXC_LOAD_GUEST_PAGE_FAULT:
        case EXC_LOAD_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected load page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }

        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            notice_failure();
            printf("Unexepected interrupt at 0x%lx: 0x%lx\n", csr_read(CSR_SEPC), scause);
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

__attribute__((naked, aligned(4))) void noexec_entry_point(void) {
    SAVE_CONTEXT();
    struct trap_context *tc = GET_TRAP_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_INST_GUEST_PAGE_FAULT:
        case EXC_INST_PAGE_FAULT: {
            notice_success();
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(tc->ra, 1));
            break;
        }
        case EXC_LOAD_GUEST_PAGE_FAULT:
        case EXC_LOAD_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected load page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        case EXC_STORE_GUEST_PAGE_FAULT:
        case EXC_STORE_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected store page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            notice_failure();
            printf("Unexepected interrupt at 0x%lx: 0x%lx\n", csr_read(CSR_SEPC), scause);
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            panic();
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

__attribute__((naked, aligned(4))) void exec_nowrite_entry_point(void) {
    SAVE_CONTEXT();
    struct trap_context *tc = GET_TRAP_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_INST_GUEST_PAGE_FAULT:
        case EXC_INST_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected load page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(tc->ra, 1));
            break;
        }
        case EXC_STORE_GUEST_PAGE_FAULT:
        case EXC_STORE_PAGE_FAULT: {
            notice_success();
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 2));
            break;
        }
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            notice_failure();
            printf("Unexepected interrupt at 0x%lx: 0x%lx\n", csr_read(CSR_SEPC), scause);
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

__attribute__((naked, aligned(4))) void exec_noread_nowrite_entry_point(void) {
    SAVE_CONTEXT();
    struct trap_context *tc = GET_TRAP_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_INST_GUEST_PAGE_FAULT:
        case EXC_INST_PAGE_FAULT: {
            notice_failure();
            printf("Unexepected load page fault at 0x%lx\n", csr_read(CSR_STVAL));
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(tc->ra, 1));
            break;
        }
        case EXC_STORE_GUEST_PAGE_FAULT:
        case EXC_STORE_PAGE_FAULT: {
            notice_success();
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 2));
            break;
        }
        case EXC_LOAD_GUEST_PAGE_FAULT:
        case EXC_LOAD_PAGE_FAULT: {
            notice_success();
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 2));
            break;
        }
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            notice_failure();
            printf("Unexepected interrupt at 0x%lx: 0x%lx\n", csr_read(CSR_SEPC), scause);
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

void set_stvec_s(vec_f entry_point) {
    asm volatile("csrw stvec, %0" ::"r"(entry_point) : "memory");
}

void set_stvec_u(vec_f entry_point) {
    call_set_stvec(entry_point);
}

void set_stvec_vs(vec_f entry_point) {
    call_set_stvec(entry_point);
}

void flush_tlb_s(void) {
    flush_tlb();
}

void flush_tlb_u(void) {
    call_flush_tlb();
}

void flush_htlb_vs(void) {
    call_flush_htlb();
}

/**
 * Tries to read but entries are invalid
 */
void test_satp_invalid(stvec_f set_stvec, vec_f entry_point, tlb_f flush_tlb, uint64_t flags) {
    set_stvec(entry_point);

    FLAG_SET(mapping[MAPPING_LVL3].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL2].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL1].associated_pte, flags);
    flush_tlb();

    char *words[2] = {"Valid", "User"};
    int i = 0;
    if (flags & FLAG_VALID)
        i = 1;

    printf("\t- %s required (1GB): ", words[i]);
    test_satp_noread(MAPPING_LVL3);

    printf("\t- %s required (2MB): ", words[i]);
    test_satp_noread(MAPPING_LVL2);

    printf("\t- %s required (4KB): ", words[i]);
    test_satp_noread(MAPPING_LVL1);
}

/**
 * Tries to read and write but entries are read-only
 */
void test_satp_rodata(stvec_f set_stvec, vec_f entry_point, tlb_f flush_tlb, uint64_t flags) {
    set_stvec(entry_point);

    FLAG_SET(mapping[MAPPING_LVL3].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL2].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL1].associated_pte, flags);
    flush_tlb();

    printf("\t- Read works (1GB): ");
    test_satp_read(MAPPING_LVL3);

    printf("\t- Read works (2MB): ");
    test_satp_read(MAPPING_LVL2);

    printf("\t- Read works (4KB): ");
    test_satp_read(MAPPING_LVL1);

    printf("\t- Store required (1GB): ");
    test_satp_nowrite(MAPPING_LVL3);

    printf("\t- Store required (2MB): ");
    test_satp_nowrite(MAPPING_LVL2);

    printf("\t- Store required (4KB): ");
    test_satp_nowrite(MAPPING_LVL1);
}

/**
 * Tries to write and exec but entries are read/write only
 */
void test_satp_data(stvec_f set_stvec, vec_f entry_point, tlb_f flush_tlb, uint64_t flags) {
    set_stvec(entry_point);

    FLAG_SET(mapping[MAPPING_LVL3].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL2].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL1].associated_pte, flags);
    flush_tlb();

    printf("\t- Store works (1GB): ");
    test_satp_write(MAPPING_LVL3);

    printf("\t- Store works (2MB): ");
    test_satp_write(MAPPING_LVL2);

    printf("\t- Store works (4KB): ");
    test_satp_write(MAPPING_LVL1);

    printf("\t- Exec required (1GB): ");
    test_satp_noexec(MAPPING_LVL3);

    printf("\t- Exec required (2MB): ");
    test_satp_noexec(MAPPING_LVL2);

    printf("\t- Exec required (4KB): ");
    test_satp_noexec(MAPPING_LVL1);
}

/**
 * Tries to read, write and exec but entries are read/exec only
 */
void test_satp_code(stvec_f set_stvec, vec_f entry_point, tlb_f flush_tlb, uint64_t flags) {
    set_stvec(entry_point);

    FLAG_SET(mapping[MAPPING_LVL3].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL2].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL1].associated_pte, flags);
    flush_tlb();

    printf("\t- Exec works (1GB): ");
    test_satp_exec(MAPPING_LVL3);

    printf("\t- Exec works (2MB): ");
    test_satp_exec(MAPPING_LVL2);

    printf("\t- Exec works (4KB): ");
    test_satp_exec(MAPPING_LVL1);

    printf("\t- Read works (1GB): ");
    test_satp_read(MAPPING_LVL3);

    printf("\t- Read works (2MB): ");
    test_satp_read(MAPPING_LVL2);

    printf("\t- Read works (4KB): ");
    test_satp_read(MAPPING_LVL1);

    printf("\t- Store required (1GB): ");
    test_satp_nowrite(MAPPING_LVL3);

    printf("\t- Store required (2MB): ");
    test_satp_nowrite(MAPPING_LVL2);

    printf("\t- Store required (4KB): ");
    test_satp_nowrite(MAPPING_LVL1);
}

/**
 * Tries to read, write and exec but entries are exec only
 */
void test_satp_private_code(stvec_f set_stvec, vec_f entry_point, tlb_f flush_tlb, uint64_t flags) {
    set_stvec(entry_point);

    FLAG_SET(mapping[MAPPING_LVL3].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL2].associated_pte, flags);
    FLAG_SET(mapping[MAPPING_LVL1].associated_pte, flags);
    flush_tlb();

    printf("\t- Exec works (1GB): ");
    test_satp_exec(MAPPING_LVL3);

    printf("\t- Exec works (2MB): ");
    test_satp_exec(MAPPING_LVL2);

    printf("\t- Exec works (4KB): ");
    test_satp_exec(MAPPING_LVL1);

    printf("\t- Read required (1GB): ");
    test_satp_noread(MAPPING_LVL3);

    printf("\t- Read required (2MB): ");
    test_satp_noread(MAPPING_LVL2);

    printf("\t- Read required (4KB): ");
    test_satp_noread(MAPPING_LVL1);

    printf("\t- Store required (1GB): ");
    test_satp_nowrite(MAPPING_LVL3);

    printf("\t- Store required (2MB): ");
    test_satp_nowrite(MAPPING_LVL2);

    printf("\t- Store required (4KB): ");
    test_satp_nowrite(MAPPING_LVL1);
}

void test_satp(void) {
    printf("Starting test: HS-mode (satp)\n");

    csr_clear(CSR_SCAUSE, SR_SIE);
    csr_write(CSR_SATP, MAKE_SATP(SATP_ROOT, SATP_MODE_39));
    flush_tlb();

    printf("    * invalid (R----) *\n");
    test_satp_invalid(set_stvec_s, &noread_entry_point, flush_tlb_s, FLAG_READ);

    printf("    * rodata (R---V) *\n");
    test_satp_rodata(set_stvec_s, &nowrite_entry_point, flush_tlb_s, FLAG_READ | FLAG_VALID);

    printf("    * data (RW--V) *\n");
    test_satp_data(set_stvec_s, &noexec_entry_point, flush_tlb_s, FLAG_READ | FLAG_WRITE | FLAG_VALID);

    printf("    * code (R-X-V) *\n");
    test_satp_code(set_stvec_s, &exec_nowrite_entry_point, flush_tlb_s, FLAG_READ | FLAG_EXEC | FLAG_VALID);

    printf("    * code (--X-V) *\n");
    test_satp_private_code(set_stvec_s, &exec_noread_nowrite_entry_point, flush_tlb_s, FLAG_EXEC | FLAG_VALID);
}

void test_vsatp(void) {
    printf("Starting test: VS-mode (vsatp)\n");

    uint64_t satp_root = MAKE_SATP(SATP_ROOT, SATP_MODE_39);

    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSATP, 0ul); // vs page table
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG,
              bit(EXC_LOAD_MISALIGNED) | bit(EXC_LOAD_ACCESS) | bit(EXC_STORE_MISALIGNED) | bit(EXC_STORE_ACCESS) | bit(EXC_LOAD_PAGE_FAULT) |
                  bit(EXC_STORE_PAGE_FAULT) | bit(EXC_INST_PAGE_FAULT)); // hypervisor exception delegation
    // EXC_LOAD_ADDRESS EXC_LOAD_ACCESS EXC_STORE_ADDRESS EXC_STORE_ACCESS
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_SEPC, &&vm_land); // vm entry point
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration
    csr_write(CSR_HGATP, 0ul); // nested page table
    flush_htlb();
    asm volatile goto("sret" :: ::host_entry_point);

vm_land: // from here we are running in VS-mode
    csr_write(CSR_STVEC, &panic_vector);
    csr_write(CSR_SATP, satp_root);
    flush_tlb();

    printf("    * nouser (R----) *\n");
    test_satp_invalid(set_stvec_s, &noread_entry_point, flush_tlb_s, FLAG_READ);

    printf("    * rodata (R---V) *\n");
    test_satp_rodata(set_stvec_s, &nowrite_entry_point, flush_tlb_s, FLAG_READ | FLAG_VALID);

    printf("    * data (RW--V) *\n");
    test_satp_data(set_stvec_s, &noexec_entry_point, flush_tlb_s, FLAG_READ | FLAG_WRITE | FLAG_VALID);

    printf("    * code (R-X-V) *\n");
    test_satp_code(set_stvec_s, &exec_nowrite_entry_point, flush_tlb_s, FLAG_READ | FLAG_EXEC | FLAG_VALID);

    printf("    * code (--X-V) *\n");
    test_satp_private_code(set_stvec_s, &exec_noread_nowrite_entry_point, flush_tlb_s, FLAG_EXEC | FLAG_VALID);

    change_mode(); // from here we are running in HS-mode

    printf("    * satp and vsatp coherency *\n");
    printf("\t- Check: ");
    if (csr_read(CSR_SATP) == 0 && csr_read(CSR_VSATP) == satp_root) {
        notice_success();
    } else {
        notice_failure();
    }
    goto end;

host_entry_point: {
    asm volatile(".align 4\n1:");
    SAVE_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            panic();
            break;
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

end:
    return;
}

void test_hgatp(void) {
    printf("Starting test: VS-mode (hgatp)\n");

    asm volatile goto("la a6, 1f\n"
                      "csrw stvec, a6" ::
                          : "memory", "a6"
                      : host_entry_point);
    csr_set(CSR_VSSTATUS, csr_read(CSR_SSTATUS));
    csr_write(CSR_VSTVEC, &panic); // VS interrupt vector
    csr_write(CSR_VSATP, 0ul); // vs page table
    csr_write(CSR_VSIE, 0ul); // interrupts vs control
    csr_write(CSR_HIE, 0ul); // interrupts h control
    csr_write(CSR_HIDELEG, 0ul); // hypervisor interrupt delegation
    csr_write(CSR_HEDELEG,
              bit(EXC_LOAD_MISALIGNED) | bit(EXC_LOAD_ACCESS) | bit(EXC_STORE_MISALIGNED) | bit(EXC_STORE_ACCESS) | bit(EXC_LOAD_PAGE_FAULT) |
                  bit(EXC_STORE_PAGE_FAULT) | bit(EXC_INST_PAGE_FAULT)); // hypervisor exception delegation
    // EXC_LOAD_ADDRESS EXC_LOAD_ACCESS EXC_STORE_ADDRESS EXC_STORE_ACCESS
    csr_write(CSR_HCOUNTEREN, 0ul); // hypervisor counter controls
    csr_write(CSR_HENVCFG, ENVCFG_CBIE | ENVCFG_CBCFE | ENVCFG_CBZE); // hypervisor environment controls
    csr_write(CSR_SEPC, &&vm_land); // vm entry point
    csr_set(CSR_SSTATUS, SR_SPP); // making sure the guest will start in VS mode
    csr_write(CSR_HSTATUS, HSTATUS_SPV | HSTATUS_SPVP); // hypervisor status configuration
    csr_write(CSR_VSATP, 0ul);
    csr_write(CSR_HGATP, MAKE_SATP(HGATP_ROOT, SATP_MODE_39)); // nested page table
    flush_htlb();
    asm volatile("sret");

vm_land: // from here we are running in VS-mode
    csr_write(CSR_STVEC, &panic_vector);
    flush_tlb();

    printf("    * nouser (R----) *\n");
    test_satp_invalid(set_stvec_vs, &noread_entry_point, flush_htlb_vs, FLAG_READ);

    printf("    * rodata (R---V) *\n");
    test_satp_rodata(set_stvec_vs, &nowrite_entry_point, flush_htlb_vs, FLAG_READ | FLAG_VALID);

    printf("    * data (RW--V) *\n");
    test_satp_data(set_stvec_vs, &noexec_entry_point, flush_htlb_vs, FLAG_READ | FLAG_WRITE | FLAG_VALID);

    printf("    * code (R-X-V) *\n");
    test_satp_code(set_stvec_vs, &exec_nowrite_entry_point, flush_htlb_vs, FLAG_READ | FLAG_EXEC | FLAG_VALID);

    printf("    * code (--X-V) *\n");
    test_satp_private_code(set_stvec_vs, &exec_noread_nowrite_entry_point, flush_htlb_vs, FLAG_EXEC | FLAG_VALID);

    change_mode(); // from here we are running in HS-mode

    goto end;

host_entry_point: {
    asm volatile(".align 4\n1:");
    SAVE_CONTEXT();
    uint64_t scause = csr_read(CSR_SCAUSE);
    switch (scause) {
        case EXC_VS_SYSCALL: {
            if (handle_vs_call() == EXTRA_UNKNOWN) {
                panic();
            }
            csr_write(CSR_SEPC, NEXT_INSTRUCTION(csr_read(CSR_SEPC), 1));
            break;
        }
        default: {
            panic();
            break;
        }
    }
    RESTORE_CONTEXT();
    asm volatile("sret");
}

end:
    return;
}
