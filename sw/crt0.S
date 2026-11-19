/*=============================================================================
 * File: crt0.S
 * Description: Bare-metal startup code and C runtime initialization for RV32I.
 *============================================================================*/

    .section .text.init
    .global _start
    .type _start, @function

_start:
    .option push
    .option arch, +zicsr
    /* Set trap vector to default handler */
    la t0, trap_handler
    csrw mtvec, t0

    /* Configure memory region attributes (MRAC CSR 0x7C0):
     * Set Region 0 (and all regions) to non-cacheable side-effect (0xAAAAAAAA).
     * This ensures exact-sized load/store bus accesses without speculative 64-bit line fetches.
     */
    li t0, 0xAAAAAAAA
    csrw 0x7c0, t0
    fence
    .option pop

    /* Initialize stack pointer */
    la sp, _stack_top

    /* Zero out BSS section */
    la t0, _bss_start
    la t1, _bss_end
zero_bss_loop:
    bgeu t0, t1, copy_data
    sw zero, 0(t0)
    addi t0, t0, 4
    j zero_bss_loop

copy_data:
    /* Copy data section from ROM/IMEM to RAM/DMEM */
    la t0, _data_start
    la t1, _data_end
    la t2, _data_load
    beq t0, t2, call_main
copy_data_loop:
    bgeu t0, t1, call_main
    lw t3, 0(t2)
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j copy_data_loop

call_main:
    /* Call C main function */
    call main

    /* If main returns 0, loop gracefully. If non-zero, trigger fail indicator */
    beqz a0, hang
    li t0, 0x00002200    /* GPIO_BASE */
    li t1, 0xFF
    sw t1, 0(t0)        /* GPIO_DIR = 0xFF */
    li t1, 0x02
    sw t1, 4(t0)        /* GPIO_OUT = 0x02 (FAIL) */

hang:
    j hang

    .size _start, . - _start

/* Default Trap Handler */
    .align 4
    .global trap_handler
trap_handler:
    .option push
    .option arch, +zicsr
    /* Read mcause into t2 */
    csrr t2, mcause
    .option pop
    /* Check if it was an interrupt (bit 31 set) */
    bltz t2, irq_return

    /* Synchronous exception / trap: flag failure with code 0x06 */
    li t0, 0x00002200    /* GPIO_BASE */
    li t1, 0xFF
    sw t1, 0(t0)        /* GPIO_DIR = 0xFF */
    li t1, 0x06
    sw t1, 4(t0)        /* GPIO_OUT = 0x06 (TRAP) */

trap_hang:
    j trap_hang

irq_return:
    mret
