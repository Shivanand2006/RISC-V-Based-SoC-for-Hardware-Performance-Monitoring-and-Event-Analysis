//=============================================================================
// File: perf_app.c
// Description: Main demonstration application for Hardware Performance Monitoring
//              SoC. Clears and enables all three monitor IPs, runs bubble sort
//              on a 16-word array, disables counters, reads them, and prints
//              performance statistics (Cycles, Instructions, Events, CPI x 100)
//              via UART. Flags completion and pass/fail on GPIO pins.
// Standard: C99 / RV32I bare-metal
//=============================================================================

#include "perf_regs.h"

int main(void) {
    // 16-word test dataset
    volatile uint32_t arr[16] = {
        15, 3, 9, 1, 14, 8, 2, 12, 4, 11, 7, 0, 13, 6, 10, 5
    };

    // Configure Event Counter to monitor Store transactions (Event 1)
    REG32(EVENT_CNT_REG_EVT_SEL) = EVENT_SEL_STORE;
    REG32(EVENT_CNT_REG_THRESH)  = 0; // Disable threshold compare

    // Clear all three counters
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_CLEAR;
    REG32(INSTR_CNT_REG_CTRL) = INSTR_CNT_CTRL_CLEAR;
    REG32(EVENT_CNT_REG_CTRL) = EVENT_CNT_CTRL_CLEAR;

    // Enable all three counters simultaneously
    REG32(CYCLE_CNT_REG_CTRL) = CYCLE_CNT_CTRL_EN;
    REG32(INSTR_CNT_REG_CTRL) = INSTR_CNT_CTRL_EN;
    REG32(EVENT_CNT_REG_CTRL) = EVENT_CNT_CTRL_EN;

    // Run bubble sort workload on the 16 words
    for (int i = 0; i < 15; i++) {
        for (int j = 0; j < 15 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                uint32_t tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }

    // Disable all three counters immediately after workload
    REG32(CYCLE_CNT_REG_CTRL) = 0;
    REG32(INSTR_CNT_REG_CTRL) = 0;
    REG32(EVENT_CNT_REG_CTRL) = 0;

    // Read counter values
    uint64_t cycles = read_cycle_cnt();
    uint64_t instrs = read_instr_cnt();
    uint32_t events = REG32(EVENT_CNT_REG_COUNT);

    // Verify sort correctness
    int sort_ok = 1;
    for (uint32_t k = 0; k < 16; k++) {
        if (arr[k] != k) {
            sort_ok = 0;
            break;
        }
    }

    if (!sort_ok) {
        set_test_fail();
        return 1;
    }

    // Compute CPI x 100
    uint32_t cpi_x100 = 0;
    if (instrs > 0) {
        uint32_t q = 0;
        udivmod32((uint32_t)(cycles * 100ULL), (uint32_t)instrs, &q, 0);
        cpi_x100 = q;
    }

    // Print Performance Report formatted per Section 7
    uart_print("Cycles       : ");
    uart_print_dec((uint32_t)cycles);
    uart_print("\n");

    uart_print("Instructions : ");
    uart_print_dec((uint32_t)instrs);
    uart_print("\n");

    uart_print("Events (Stores): ");
    uart_print_dec(events);
    uart_print("\n");

    uart_print("CPI x100     : ");
    uart_print_dec(cpi_x100);
    uart_print("\n");

    // Print PASS token and set GPIO_OUT[0] = 1
    set_test_pass();

    return 0;
}
