//=============================================================================
// File: perf_regs.h
// Description: Register definitions, memory map addresses, bitfields, and
//              lightweight I/O helpers for RISC-V SoC firmware.
// Standard: C99 / RV32I bare-metal
//=============================================================================

#ifndef PERF_REGS_H
#define PERF_REGS_H

#include <stdint.h>

// Base Addresses
#define IMEM_BASE                0x00000000UL
#define DMEM_BASE                0x00001000UL
#define UART_BASE                0x00002000UL
#define TIMER_BASE               0x00002100UL
#define GPIO_BASE                0x00002200UL
#define CYCLE_CNT_BASE           0x00002300UL
#define INSTR_CNT_BASE           0x00002400UL
#define EVENT_CNT_BASE           0x00002500UL

// Memory-Mapped Register Access Macro
#define REG32(addr)              (*(volatile uint32_t *)(uintptr_t)(addr))

// UART Registers (16550 subset)
#define UART_REG_RBR_THR         (UART_BASE + 0x00)
#define UART_REG_IER             (UART_BASE + 0x04)
#define UART_REG_DIVISOR         (UART_BASE + 0x08)
#define UART_REG_LCR             (UART_BASE + 0x0C)
#define UART_REG_LSR             (UART_BASE + 0x14)

#define UART_LSR_DR              (1U << 0)
#define UART_LSR_THRE            (1U << 5)
#define UART_LSR_TEMT            (1U << 6)

// Timer Registers
#define TIMER_REG_CTRL           (TIMER_BASE + 0x00)
#define TIMER_REG_RELOAD         (TIMER_BASE + 0x04)
#define TIMER_REG_COUNT          (TIMER_BASE + 0x08)

#define TIMER_CTRL_EN            (1U << 0)

// GPIO Registers
#define GPIO_REG_DIR             (GPIO_BASE + 0x00)
#define GPIO_REG_OUT             (GPIO_BASE + 0x04)
#define GPIO_REG_IN              (GPIO_BASE + 0x08)

// Cycle Counter Registers
#define CYCLE_CNT_REG_CTRL       (CYCLE_CNT_BASE + 0x00)
#define CYCLE_CNT_REG_STATUS     (CYCLE_CNT_BASE + 0x04)
#define CYCLE_CNT_REG_CNT_LO     (CYCLE_CNT_BASE + 0x08)
#define CYCLE_CNT_REG_CNT_HI     (CYCLE_CNT_BASE + 0x0C)

#define CYCLE_CNT_CTRL_EN        (1U << 0)
#define CYCLE_CNT_CTRL_CLEAR     (1U << 1)
#define CYCLE_CNT_STATUS_RUNNING (1U << 0)

// Instruction Counter Registers
#define INSTR_CNT_REG_CTRL       (INSTR_CNT_BASE + 0x00)
#define INSTR_CNT_REG_STATUS     (INSTR_CNT_BASE + 0x04)
#define INSTR_CNT_REG_CNT_LO     (INSTR_CNT_BASE + 0x08)
#define INSTR_CNT_REG_CNT_HI     (INSTR_CNT_BASE + 0x0C)

#define INSTR_CNT_CTRL_EN        (1U << 0)
#define INSTR_CNT_CTRL_CLEAR     (1U << 1)
#define INSTR_CNT_STATUS_RUNNING (1U << 0)

// Performance Event Counter Registers
#define EVENT_CNT_REG_CTRL       (EVENT_CNT_BASE + 0x00)
#define EVENT_CNT_REG_EVT_SEL    (EVENT_CNT_BASE + 0x04)
#define EVENT_CNT_REG_COUNT      (EVENT_CNT_BASE + 0x08)
#define EVENT_CNT_REG_THRESH     (EVENT_CNT_BASE + 0x0C)
#define EVENT_CNT_REG_STATUS     (EVENT_CNT_BASE + 0x10)

#define EVENT_CNT_CTRL_EN        (1U << 0)
#define EVENT_CNT_CTRL_CLEAR     (1U << 1)
#define EVENT_CNT_CTRL_IRQ_EN    (1U << 2)

#define EVENT_CNT_STATUS_OVF     (1U << 0)
#define EVENT_CNT_STATUS_THRHIT  (1U << 1)
#define EVENT_CNT_STATUS_RUNNING (1U << 2)

// Event Select Indices
#define EVENT_SEL_LOAD           0U
#define EVENT_SEL_STORE          1U
#define EVENT_SEL_FETCH          2U
#define EVENT_SEL_BRANCH_JUMP    3U
#define EVENT_SEL_STALL_BUBBLE   4U
#define EVENT_SEL_EXCEPTION      5U
#define EVENT_SEL_TIMER_TICK     6U
#define EVENT_SEL_UART_TX_DONE   7U

//-----------------------------------------------------------------------------
// Bare-Metal UART and Helper Functions
//-----------------------------------------------------------------------------

static inline void uart_putc(char c) {
    while (!(REG32(UART_REG_LSR) & UART_LSR_THRE)) {
        // Wait until transmitter holding register is empty
    }
    REG32(UART_REG_RBR_THR) = (uint32_t)(uint8_t)c;
}

static inline void uart_print(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putc('\r');
        }
        uart_putc(*str++);
    }
}

static inline void uart_print_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_print("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}

// Software 32-bit unsigned division and modulo without libgcc dependency
static inline void udivmod32(uint32_t num, uint32_t den, uint32_t *quot, uint32_t *rem) {
    if (den == 0) {
        if (quot) *quot = 0;
        if (rem)  *rem  = 0;
        return;
    }
    uint32_t q = 0;
    uint32_t r = 0;
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((num >> i) & 1U);
        if (r >= den) {
            r -= den;
            q |= (1U << i);
        }
    }
    if (quot) *quot = q;
    if (rem)  *rem  = r;
}

static inline void uart_print_dec(uint32_t val) {
    char buf[12];
    int idx = 0;
    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0) {
        uint32_t q, r;
        udivmod32(val, 10, &q, &r);
        buf[idx++] = (char)('0' + r);
        val = q;
    }
    while (idx > 0) {
        uart_putc(buf[--idx]);
    }
}

static inline uint64_t read_cycle_cnt(void) {
    // Read CNT_LO first to latch CNT_HI into shadow register
    uint32_t lo = REG32(CYCLE_CNT_REG_CNT_LO);
    uint32_t hi = REG32(CYCLE_CNT_REG_CNT_HI);
    return (((uint64_t)hi) << 32) | lo;
}

static inline uint64_t read_instr_cnt(void) {
    // Read CNT_LO first to latch CNT_HI into shadow register
    uint32_t lo = REG32(INSTR_CNT_REG_CNT_LO);
    uint32_t hi = REG32(INSTR_CNT_REG_CNT_HI);
    return (((uint64_t)hi) << 32) | lo;
}

static inline void set_test_pass(void) {
    uart_print("PASS\n");
    while (!(REG32(UART_REG_LSR) & UART_LSR_TEMT)) {
        // Wait for serial transmission to complete
    }
    REG32(GPIO_REG_DIR) = 0xFF;
    REG32(GPIO_REG_OUT) = 0x01; // GPIO_OUT[0] = 1
}

static inline void set_test_fail(void) {
    uart_print("FAIL\n");
    while (!(REG32(UART_REG_LSR) & UART_LSR_TEMT)) {
        // Wait for serial transmission to complete
    }
    REG32(GPIO_REG_DIR) = 0xFF;
    REG32(GPIO_REG_OUT) = 0x02; // GPIO_OUT[1] = 1
}

#endif // PERF_REGS_H
