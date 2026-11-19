//=============================================================================
// File: test_instr.c
// Description: Bare-metal test for Instruction Counter IP.
//              Verifies retired instruction counting on a known loop and
//              verifies cycles >= instructions.
//=============================================================================

#include "perf_regs.h"

int main(void) {
    uart_print("\n=== Running test_instr ===\n");

    // Clear both cycle and instruction counters
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_CLEAR;
    REG32(INSTR_CNT_REG_CTRL) = INSTR_CNT_CTRL_CLEAR;

    // Enable both counters simultaneously
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_EN;
    REG32(INSTR_CNT_REG_CTRL) = INSTR_CNT_CTRL_EN;

    // Execute exactly 100 NOP instructions in assembly
    __asm__ volatile(
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
        "nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n nop\n"
    );

    // Stop counters
    REG32(CYCLE_CNT_REG_CTRL) = 0;
    REG32(INSTR_CNT_REG_CTRL) = 0;

    uint64_t cycles = read_cycle_cnt();
    uint64_t instrs = read_instr_cnt();

    uart_print("Cycles       : ");
    uart_print_dec((uint32_t)cycles);
    uart_print("\nInstructions : ");
    uart_print_dec((uint32_t)instrs);
    uart_print("\n");

    if (instrs < 100) {
        uart_print("FAIL: Instruction count too low (<100)\n");
        set_test_fail();
        return 1;
    }

    if (cycles < instrs) {
        uart_print("FAIL: Cycles must be >= instructions\n");
        set_test_fail();
        return 1;
    }

    uart_print("test_instr PASSED\n");
    set_test_pass();
    return 0;
}
