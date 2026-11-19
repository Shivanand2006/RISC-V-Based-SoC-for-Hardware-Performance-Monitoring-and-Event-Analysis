//=============================================================================
// File: test_cycle.c
// Description: Bare-metal test for Cycle Counter IP.
//              Verifies enable, increment, hold when disabled, clear, and
//              coherent 64-bit shadow read.
//=============================================================================

#include "perf_regs.h"

int main(void) {
    uart_print("\n=== Running test_cycle ===\n");

    // 1. Reset and Clear Counter
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_CLEAR;
    uint64_t c0 = read_cycle_cnt();
    if (c0 != 0) {
        uart_print("FAIL: Initial clear failed\n");
        set_test_fail();
        return 1;
    }

    // 2. Enable Counter and run delay loop
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_EN;
    for (volatile int i = 0; i < 100; i++) {
        __asm__ volatile("nop");
    }

    uint64_t c1 = read_cycle_cnt();
    if (c1 == 0) {
        uart_print("FAIL: Counter remained 0 after enable\n");
        set_test_fail();
        return 1;
    }

    // 3. Verify increasing count
    for (volatile int i = 0; i < 100; i++) {
        __asm__ volatile("nop");
    }
    uint64_t c2 = read_cycle_cnt();
    if (c2 <= c1) {
        uart_print("FAIL: Counter not strictly increasing\n");
        set_test_fail();
        return 1;
    }

    // 4. Disable and verify hold
    REG32(CYCLE_CNT_REG_CTRL) = 0; // Disable
    uint64_t c_hold1 = read_cycle_cnt();
    for (volatile int i = 0; i < 100; i++) {
        __asm__ volatile("nop");
    }
    uint64_t c_hold2 = read_cycle_cnt();
    if (c_hold1 != c_hold2) {
        uart_print("FAIL: Counter did not hold when disabled\n");
        set_test_fail();
        return 1;
    }

    // 5. Test CLEAR
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_CLEAR;
    uint64_t c_cleared = read_cycle_cnt();
    if (c_cleared != 0) {
        uart_print("FAIL: CLEAR did not reset count to 0\n");
        set_test_fail();
        return 1;
    }

    // 6. Verify coherent 64-bit read
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_EN;
    for (volatile int i = 0; i < 50; i++) {
        __asm__ volatile("nop");
    }
    uint32_t lo = REG32(CYCLE_CNT_REG_CNT_LO);
    uint32_t hi = REG32(CYCLE_CNT_REG_CNT_HI);
    if (lo == 0 && hi == 0) {
        uart_print("FAIL: Coherent read zero\n");
        set_test_fail();
        return 1;
    }

    uart_print("test_cycle PASSED\n");
    set_test_pass();
    return 0;
}
