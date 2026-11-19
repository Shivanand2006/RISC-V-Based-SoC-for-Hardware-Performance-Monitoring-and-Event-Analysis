//=============================================================================
// File: test_event.c
// Description: Bare-metal test for Performance Event Counter IP.
//              Stimulates events (loads, stores, branches), verifies event counts,
//              and validates threshold detection and W1C status clear.
//=============================================================================

#include "perf_regs.h"

int main(void) {
    uart_print("\n=== Running test_event ===\n");

    volatile uint32_t *dmem = (volatile uint32_t *)(DMEM_BASE + 0x100);

    // -------------------------------------------------------------------------
    // Test 1: Store Event (EVENT_SEL = 1)
    // -------------------------------------------------------------------------
    REG32(EVENT_CNT_REG_EVT_SEL) = EVENT_SEL_STORE;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_CLEAR;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_EN;

    for (int i = 0; i < 10; i++) {
        dmem[i] = (uint32_t)(0xAA00 + i);
    }

    REG32(EVENT_CNT_REG_CTRL) = 0; // Disable
    uint32_t store_count = REG32(EVENT_CNT_REG_COUNT);
    uart_print("Store Events (min 10)  : ");
    uart_print_dec(store_count);
    uart_print("\n");

    if (store_count < 10) {
        uart_print("FAIL: Store event count too low\n");
        set_test_fail();
        return 1;
    }

    // -------------------------------------------------------------------------
    // Test 2: Load Event (EVENT_SEL = 0)
    // -------------------------------------------------------------------------
    REG32(EVENT_CNT_REG_EVT_SEL) = EVENT_SEL_LOAD;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_CLEAR;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_EN;

    volatile uint32_t sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += dmem[i];
    }

    REG32(EVENT_CNT_REG_CTRL) = 0; // Disable
    uint32_t load_count = REG32(EVENT_CNT_REG_COUNT);
    uart_print("Load Events (min 10)   : ");
    uart_print_dec(load_count);
    uart_print("\n");

    if (load_count < 10) {
        uart_print("FAIL: Load event count too low\n");
        set_test_fail();
        return 1;
    }

    // -------------------------------------------------------------------------
    // Test 3: Branch / Jump Event (EVENT_SEL = 3)
    // -------------------------------------------------------------------------
    REG32(EVENT_CNT_REG_EVT_SEL) = EVENT_SEL_BRANCH_JUMP;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_CLEAR;
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_EN;

    for (volatile int j = 0; j <= 20; j++) {
        __asm__ volatile("nop");
    }

    REG32(EVENT_CNT_REG_CTRL) = 0; // Disable
    uint32_t branch_count = REG32(EVENT_CNT_REG_COUNT);
    uart_print("Branch Events (min 19) : ");
    uart_print_dec(branch_count);
    uart_print("\n");

    if (branch_count < 19) {
        uart_print("FAIL: Branch event count too low\n");
        set_test_fail();
        return 1;
    }

    // -------------------------------------------------------------------------
    // Test 4: Threshold and W1C Status Clear
    // -------------------------------------------------------------------------
    REG32(EVENT_CNT_REG_EVT_SEL) = EVENT_SEL_STORE;
    REG32(EVENT_CNT_REG_THRESH)  = 5; // Threshold = 5
    REG32(EVENT_CNT_REG_CTRL)    = EVENT_CNT_CTRL_CLEAR;

    // Verify THRESH_HIT is 0 initially
    if (REG32(EVENT_CNT_REG_STATUS) & EVENT_CNT_STATUS_THRHIT) {
        uart_print("FAIL: THRESH_HIT set after clear\n");
        set_test_fail();
        return 1;
    }

    REG32(EVENT_CNT_REG_CTRL) = EVENT_CNT_CTRL_EN;

    // Perform 8 stores
    for (int i = 0; i < 8; i++) {
        dmem[i] = (uint32_t)(0x5500 + i);
    }
    REG32(EVENT_CNT_REG_CTRL) = 0; // Disable

    // Verify THRESH_HIT is now asserted
    if (!(REG32(EVENT_CNT_REG_STATUS) & EVENT_CNT_STATUS_THRHIT)) {
        uart_print("FAIL: THRESH_HIT not asserted after 8 stores\n");
        set_test_fail();
        return 1;
    }

    // Clear THRESH_HIT via W1C
    REG32(EVENT_CNT_REG_STATUS) = EVENT_CNT_STATUS_THRHIT;
    if (REG32(EVENT_CNT_REG_STATUS) & EVENT_CNT_STATUS_THRHIT) {
        uart_print("FAIL: THRESH_HIT not cleared by W1C\n");
        set_test_fail();
        return 1;
    }

    uart_print("test_event PASSED\n");
    set_test_pass();
    return 0;
}
