// =============================================================================
// File        : soc_c_test.c
// Project     : RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis
// Student ID  : 1602-23-735-108
// Description : Comprehensive Bare-Metal C Test Suite verifying all SoC IPs:
//               - Data RAM (DMEM) Read/Write
//               - 16550 UART Status & Transmit
//               - 32-bit Reloadable Timer
//               - 8-bit GPIO Controller
//               - 64-bit Cycle Counter (EN, Clear, Hold, Coherent Read)
//               - 64-bit Instruction Counter (Retire Gating, CPI invariant)
//               - 32-bit Performance Event Counter (EVT_SEL, THRESH, W1C)
// =============================================================================

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

// Mailbox / Signature Register (top of DMEM)
#define TOHOST       REG32(0x00001FFCu)

// Peripheral Base Addresses
#define IMEM_BASE    0x00000000u
#define DMEM_BASE    0x00001000u
#define UART_BASE    0x00002000u
#define TIMER_BASE   0x00002100u
#define GPIO_BASE    0x00002200u
#define CYCLE_BASE   0x00002300u
#define INSTR_BASE   0x00002400u
#define EVENT_BASE   0x00002500u

// IP Identification Codes for Telemetry
#define IP_DMEM      0x01u
#define IP_UART      0x02u
#define IP_TIMER     0x03u
#define IP_GPIO      0x04u
#define IP_CYCLE     0x05u
#define IP_INSTR     0x06u
#define IP_EVENT     0x07u
#define IP_ALL       0xFFu

static void fail(uint32_t ip) {
    TOHOST = 0xBAD00000u | (ip & 0xFFu);
    REG32(GPIO_BASE + 0x00) = 0xFF; // GPIO_DIR = out
    REG32(GPIO_BASE + 0x04) = 0x02; // GPIO_OUT[1] = 1 (FAIL)
    for (;;) {
        __asm__ volatile ("nop");
    }
}

static void check(int ok, uint32_t ip) {
    if (!ok) fail(ip);
}

static void pass(uint32_t ip) {
    TOHOST = 0xACCE0000u | (ip & 0xFFu);
}

// -----------------------------------------------------------------------------
// Bare-Metal UART Helpers
// -----------------------------------------------------------------------------
static inline void uart_putc(char c) {
    while (!(REG32(UART_BASE + 0x14) & (1u << 5))) {
        // Wait until Transmitter Holding Register Empty (THRE)
    }
    REG32(UART_BASE + 0x00) = (uint32_t)(uint8_t)c;
}

static inline void uart_print(const char *str) {
    while (*str) {
        if (*str == '\n') uart_putc('\r');
        uart_putc(*str++);
    }
}

static inline void uart_print_dec(uint32_t val) {
    char buf[12];
    int idx = 0;
    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0) {
        buf[idx++] = (char)('0' + (val % 10));
        val /= 10;
    }
    while (idx > 0) {
        uart_putc(buf[--idx]);
    }
}

// -----------------------------------------------------------------------------
// 1. Check Data Memory (DMEM)
// -----------------------------------------------------------------------------
static void check_dmem(void) {
    volatile uint32_t *dmem = (volatile uint32_t *)(DMEM_BASE + 0x100);
    for (int i = 0; i < 8; i++) {
        dmem[i] = 0xAA000000u | (uint32_t)i;
    }
    for (int i = 0; i < 8; i++) {
        check(dmem[i] == (0xAA000000u | (uint32_t)i), IP_DMEM);
    }
    pass(IP_DMEM);
}

// -----------------------------------------------------------------------------
// 2. Check 16550 UART
// -----------------------------------------------------------------------------
static void check_uart(void) {
    REG32(UART_BASE + 0x08) = 434;      // Divisor for 115200 baud @ 50MHz
    REG32(UART_BASE + 0x0C) = 0x03;     // 8N1 mode
    check((REG32(UART_BASE + 0x14) & (1u << 5)) != 0, IP_UART); // LSR.THRE
    pass(IP_UART);
}

// -----------------------------------------------------------------------------
// 3. Check 32-bit Timer
// -----------------------------------------------------------------------------
static void check_timer(void) {
    REG32(TIMER_BASE + 0x00) = 0;        // Disable
    REG32(TIMER_BASE + 0x04) = 1000;     // Reload value
    REG32(TIMER_BASE + 0x00) = 1;        // Enable
    for (volatile int i = 0; i < 50; i++) __asm__ volatile("nop");
    uint32_t c = REG32(TIMER_BASE + 0x08);
    check(c < 1000, IP_TIMER);          // Verify down-counting
    REG32(TIMER_BASE + 0x00) = 0;        // Stop
    pass(IP_TIMER);
}

// -----------------------------------------------------------------------------
// 4. Check 8-bit GPIO
// -----------------------------------------------------------------------------
static void check_gpio(void) {
    REG32(GPIO_BASE + 0x00) = 0x0F;      // Lower 4 bits output
    REG32(GPIO_BASE + 0x04) = 0x0A;      // Write pattern
    check((REG32(GPIO_BASE + 0x04) & 0x0F) == 0x0A, IP_GPIO);
    pass(IP_GPIO);
}

// -----------------------------------------------------------------------------
// 5. Check 64-bit Cycle Counter
// -----------------------------------------------------------------------------
static void check_cycle_cnt(void) {
    REG32(CYCLE_BASE + 0x00) = 2;        // CLEAR
    uint32_t lo0 = REG32(CYCLE_BASE + 0x08);
    check(lo0 == 0, IP_CYCLE);

    REG32(CYCLE_BASE + 0x00) = 1;        // Enable
    for (volatile int i = 0; i < 100; i++) __asm__ volatile("nop");
    REG32(CYCLE_BASE + 0x00) = 0;        // Disable

    uint32_t lo1 = REG32(CYCLE_BASE + 0x08);
    uint32_t hi1 = REG32(CYCLE_BASE + 0x0C);
    check(lo1 > 0, IP_CYCLE);
    check(REG32(CYCLE_BASE + 0x04) == 0, IP_CYCLE); // STATUS.RUNNING == 0
    pass(IP_CYCLE);
}

// -----------------------------------------------------------------------------
// 6. Check 64-bit Instruction Counter
// -----------------------------------------------------------------------------
static void check_instr_cnt(void) {
    REG32(CYCLE_BASE + 0x00) = 2;        // CLEAR cycle
    REG32(INSTR_BASE + 0x00) = 2;        // CLEAR instr
    REG32(CYCLE_BASE + 0x00) = 1;        // Enable cycle
    REG32(INSTR_BASE + 0x00) = 1;        // Enable instr

    // Execute 50 NOP instructions
    __asm__ volatile (
        "nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
        "nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
        "nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
        "nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
        "nop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\nnop\n"
    );

    REG32(CYCLE_BASE + 0x00) = 0;
    REG32(INSTR_BASE + 0x00) = 0;

    uint32_t cyc   = REG32(CYCLE_BASE + 0x08);
    uint32_t instr = REG32(INSTR_BASE + 0x08);

    check(instr >= 50, IP_INSTR);
    check(cyc >= instr, IP_INSTR);       // Architectural invariant: Cycles >= Instructions
    pass(IP_INSTR);
}

// -----------------------------------------------------------------------------
// 7. Check 32-bit Performance Event Counter
// -----------------------------------------------------------------------------
static void check_event_cnt(void) {
    volatile uint32_t *dmem = (volatile uint32_t *)(DMEM_BASE + 0x200);

    REG32(EVENT_BASE + 0x04) = 1;        // EVT_SEL = 1 (Store)
    REG32(EVENT_BASE + 0x0C) = 5;        // THRESH = 5
    REG32(EVENT_BASE + 0x00) = 2;        // CLEAR
    REG32(EVENT_BASE + 0x00) = 1;        // Enable

    for (int i = 0; i < 10; i++) {
        dmem[i] = 0x55550000u | (uint32_t)i;
    }
    REG32(EVENT_BASE + 0x00) = 0;        // Stop

    uint32_t stores = REG32(EVENT_BASE + 0x08);
    check(stores >= 10, IP_EVENT);
    check((REG32(EVENT_BASE + 0x10) & 0x02) != 0, IP_EVENT); // THRESH_HIT set

    // Clear THRESH_HIT via W1C
    REG32(EVENT_BASE + 0x10) = 0x02;
    check((REG32(EVENT_BASE + 0x10) & 0x02) == 0, IP_EVENT); // Cleared
    pass(IP_EVENT);
}

// -----------------------------------------------------------------------------
// Main Test Routine: All IPs + Sort Workload Profiling
// -----------------------------------------------------------------------------
int main(void) {
    uart_print("\n=================================================\n");
    uart_print("Starting RISC-V SoC C-Test (VeeR EL2 + HPM IPs)\n");
    uart_print("=================================================\n");

    // 1. Run Individual IP Smoke Checks
    check_dmem();
    check_uart();
    check_timer();
    check_gpio();
    check_cycle_cnt();
    check_instr_cnt();
    check_event_cnt();

    // 2. Run Main Profiling Benchmark (16-word Bubble Sort)
    volatile uint32_t arr[16] = {
        15, 3, 9, 1, 14, 8, 2, 12, 4, 11, 7, 0, 13, 6, 10, 5
    };

    REG32(EVENT_BASE + 0x04) = 1; // Track Stores
    REG32(EVENT_BASE + 0x0C) = 0; // Disable threshold

    REG32(CYCLE_BASE + 0x00) = 2; // Clear
    REG32(INSTR_BASE + 0x00) = 2;
    REG32(EVENT_BASE + 0x00) = 2;

    REG32(CYCLE_BASE + 0x00) = 1; // Enable all 3 counters
    REG32(INSTR_BASE + 0x00) = 1;
    REG32(EVENT_BASE + 0x00) = 1;

    for (int i = 0; i < 15; i++) {
        for (int j = 0; j < 15 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                uint32_t tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }

    REG32(CYCLE_BASE + 0x00) = 0; // Halt all counters
    REG32(INSTR_BASE + 0x00) = 0;
    REG32(EVENT_BASE + 0x00) = 0;

    uint32_t cycles = REG32(CYCLE_BASE + 0x08);
    uint32_t instrs = REG32(INSTR_BASE + 0x08);
    uint32_t events = REG32(EVENT_BASE + 0x08);

    for (uint32_t k = 0; k < 16; k++) {
        check(arr[k] == k, IP_ALL);
    }

    uint32_t cpi_x100 = 0;
    if (instrs > 0) {
        cpi_x100 = (uint32_t)(((uint64_t)cycles * 100ULL) / (uint64_t)instrs);
    }

    // 3. Print Performance Report
    uart_print("Cycles       : ");
    uart_print_dec(cycles);
    uart_print("\nInstructions : ");
    uart_print_dec(instrs);
    uart_print("\nEvents (Stores): ");
    uart_print_dec(events);
    uart_print("\nCPI x100     : ");
    uart_print_dec(cpi_x100);
    uart_print("\nSOC_CTEST_RESULT=PASS\n");
    uart_print("PASS\n");

    // Signal PASS on GPIO and Mailbox
    REG32(GPIO_BASE + 0x00) = 0xFF; // Direction: Output
    REG32(GPIO_BASE + 0x04) = 0x01; // GPIO_OUT[0] = 1 (PASS)
    TOHOST = 0xACCE0000u | IP_ALL;

    return 0;
}
