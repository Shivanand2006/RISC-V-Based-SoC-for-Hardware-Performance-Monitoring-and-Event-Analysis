# Address Map Specification

## RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis

---

| Field | Details |
|---|---|
| **Document Type** | Address Map Specification |
| **Student ID** | 1602-23-735-108 |
| **Revision** | 1.0 |
| **Bus Width** | 32-bit address, 32-bit data |
| **Byte Order** | Little-endian |

---

## 1. System Physical Memory Map

The SoC uses a flat 32-bit physical address space. All regions are non-overlapping and 256-byte aligned for peripheral blocks.

| Address Range | Size | Module | Description | IP Offset Origin |
|---|---|---|---|---|
| `0x0000_0000` – `0x0000_0FFF` | 4 KB | **IMEM** | Instruction memory (read-only during normal operation); reset vector at base | `0x0000_0000` |
| `0x0000_1000` – `0x0000_1FFF` | 4 KB | **DMEM** | Data memory; stack grows down from `0x0000_1FFF` | `0x0000_1000` |
| `0x0000_2000` – `0x0000_20FF` | 256 B | **UART** | 16550-subset UART (TX/RX FIFO, baud divisor, LSR) | `0x0000_2000` |
| `0x0000_2100` – `0x0000_21FF` | 256 B | **Timer** | 32-bit down-counting timer with auto-reload and interrupt | `0x0000_2100` |
| `0x0000_2200` – `0x0000_22FF` | 256 B | **GPIO** | 8-bit bidirectional GPIO (DIR / OUT / IN) | `0x0000_2200` |
| `0x0000_2300` – `0x0000_23FF` | 256 B | **Cycle Counter** | 64-bit clock-cycle counter HPM IP | `0x0000_2300` |
| `0x0000_2400` – `0x0000_24FF` | 256 B | **Instruction Counter** | 64-bit instruction retirement counter HPM IP | `0x0000_2400` |
| `0x0000_2500` – `0x0000_25FF` | 256 B | **Event Counter** | 32-bit configurable event counter with threshold interrupt | `0x0000_2500` |
| `0x0000_2600` – `0xFFFF_FFFF` | — | **Unmapped** | Returns bus error (HRESP = ERROR, `error` asserted) | — |

> [!NOTE]
> IMEM is accessible only via the IFU AHB-Lite bus. The LSU bus (and hence software) cannot write to IMEM during normal operation. DMEM is accessible only via the LSU bus.

---

## 2. Address Decoding Rules

The `bus_decoder.v` module performs hierarchical address decoding:

### 2.1 Level 1 — Page Select (addr[31:12])

The upper 20 bits select the 4 KB page:

| addr[31:12] | Page | Decoded Region |
|---|---|---|
| `20'h0_0000` | Page 0 | IMEM (`0x0000_0000` – `0x0000_0FFF`) |
| `20'h0_0001` | Page 1 | DMEM (`0x0000_1000` – `0x0000_1FFF`) |
| `20'h0_0002` | Page 2 | Peripheral space (`0x0000_2000` – `0x0000_2FFF`) |
| Any other | — | Error — unmapped |

### 2.2 Level 2 — Peripheral Select (addr[11:8])

Within peripheral page 2, bits `[11:8]` select the specific IP:

| addr[11:8] | Peripheral | Base Address |
|---|---|---|
| `4'h0` | UART | `0x0000_2000` |
| `4'h1` | Timer | `0x0000_2100` |
| `4'h2` | GPIO | `0x0000_2200` |
| `4'h3` | Cycle Counter | `0x0000_2300` |
| `4'h4` | Instruction Counter | `0x0000_2400` |
| `4'h5` | Event Counter | `0x0000_2500` |
| `4'h6` – `4'hF` | — | Error — unmapped |

### 2.3 Level 3 — Register Offset (addr[7:0])

The lowest 8 bits are passed directly to each peripheral's `reg_slave_if`. All registers are 32-bit word-aligned, so:

```
Register index = addr[7:2]    (bits [7:2] select the register word)
Byte lane      = addr[1:0]    (bits [1:0] select the byte lane within the word)
```

### 2.4 Decode Logic (Verilog Excerpt)

```verilog
// bus_decoder.v – simplified address decode
always @(*) begin
    // Default: no select, no error
    {sel_uart, sel_timer, sel_gpio, sel_ccnt, sel_icnt, sel_ecnt} = 6'b0;
    sel_err = 1'b0;

    if (req) begin
        case (addr[31:12])
            20'h00000: sel_imem  = 1'b1;
            20'h00001: sel_dmem  = 1'b1;
            20'h00002: begin
                case (addr[11:8])
                    4'h0: sel_uart  = 1'b1;
                    4'h1: sel_timer = 1'b1;
                    4'h2: sel_gpio  = 1'b1;
                    4'h3: sel_ccnt  = 1'b1;
                    4'h4: sel_icnt  = 1'b1;
                    4'h5: sel_ecnt  = 1'b1;
                    default: sel_err = 1'b1;
                endcase
            end
            default: sel_err = 1'b1;
        endcase
    end
end
```

---

## 3. Detailed Register Maps

### 3.1 Cycle Counter — Base Address `0x0000_2300`

The Cycle Counter provides a 64-bit count of enabled clock cycles with a shadow register for coherent reads.

| Absolute Addr | Offset | Register | Access | Reset Value | Description |
|---|---|---|---|---|---|
| `0x0000_2300` | `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register |
| `0x0000_2304` | `0x04` | `STATUS` | RO | `0x0000_0000` | Status register |
| `0x0000_2308` | `0x08` | `CNT_LO` | RO | `0x0000_0000` | Counter bits [31:0] *(read latches CNT_HI shadow)* |
| `0x0000_230C` | `0x0C` | `CNT_HI` | RO | `0x0000_0000` | Counter bits [63:32] *(reads from shadow)* |

#### CTRL Register (Offset 0x00)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `EN` | R/W | 0 | **Counter Enable.** 1 = counter increments each cycle; 0 = counter frozen |
| [1] | `CLR` | R/W | 0 | **Counter Clear.** Write 1 to synchronously clear counter to 0. Self-clears next cycle. |
| [31:2] | — | RO | 0 | Reserved. Read as 0. |

#### STATUS Register (Offset 0x04)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `RUNNING` | RO | 0 | 1 when EN=1 and counter is actively incrementing |
| [31:1] | — | RO | 0 | Reserved |

#### CNT_LO Register (Offset 0x08)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `CNT_LO` | RO | 0 | Lower 32 bits of the 64-bit cycle counter. **Reading this register atomically snapshots CNT_HI into the shadow register.** |

#### CNT_HI Register (Offset 0x0C)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `CNT_HI` | RO | 0 | Upper 32 bits returned from the shadow register (captured when CNT_LO was last read). |

---

### 3.2 Instruction Counter — Base Address `0x0000_2400`

The Instruction Counter provides a 64-bit count of retired instructions using the VeeR EL2 `trace_rv_i_valid_ip` retirement signal.

| Absolute Addr | Offset | Register | Access | Reset Value | Description |
|---|---|---|---|---|---|
| `0x0000_2400` | `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register |
| `0x0000_2404` | `0x04` | `STATUS` | RO | `0x0000_0000` | Status register |
| `0x0000_2408` | `0x08` | `CNT_LO` | RO | `0x0000_0000` | Retired instruction count bits [31:0] *(read latches CNT_HI shadow)* |
| `0x0000_240C` | `0x0C` | `CNT_HI` | RO | `0x0000_0000` | Retired instruction count bits [63:32] *(reads from shadow)* |

#### CTRL Register (Offset 0x00)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `EN` | R/W | 0 | **Counter Enable.** 1 = count retirement events; 0 = frozen |
| [1] | `CLR` | R/W | 0 | **Counter Clear.** Write 1 to clear. Self-clears next cycle. |
| [31:2] | — | RO | 0 | Reserved |

#### STATUS Register (Offset 0x04)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `RUNNING` | RO | 0 | 1 when actively counting retirements |
| [31:1] | — | RO | 0 | Reserved |

#### CNT_LO Register (Offset 0x08)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `CNT_LO` | RO | 0 | Lower 32 bits of retired instruction count. **Reading atomically snapshots CNT_HI.** |

#### CNT_HI Register (Offset 0x0C)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `CNT_HI` | RO | 0 | Upper 32 bits from shadow register. |

---

### 3.3 Performance Event Counter — Base Address `0x0000_2500`

The Event Counter monitors one of 8 selectable hardware events, with a 32-bit threshold comparator, sticky overflow detection, and maskable interrupt output.

| Absolute Addr | Offset | Register | Access | Reset Value | Description |
|---|---|---|---|---|---|
| `0x0000_2500` | `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register |
| `0x0000_2504` | `0x04` | `EVT_SEL` | R/W | `0x0000_0000` | Event select register |
| `0x0000_2508` | `0x08` | `COUNT` | RO | `0x0000_0000` | 32-bit event count |
| `0x0000_250C` | `0x0C` | `THRESH` | R/W | `0xFFFF_FFFF` | Threshold compare value |
| `0x0000_2510` | `0x10` | `STATUS` | R/W1C | `0x0000_0000` | Status / interrupt flags |

#### CTRL Register (Offset 0x00)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `EN` | R/W | 0 | **Counter Enable.** 1 = count selected events; 0 = frozen |
| [1] | `CLR` | R/W | 0 | **Counter Clear.** Write 1 to synchronously clear COUNT to 0. Self-clears. |
| [2] | `IRQ_EN` | R/W | 0 | **Interrupt Enable Mask.** 1 = assert `irq_o` on THRESH_HIT or OVERFLOW |
| [31:3] | — | RO | 0 | Reserved |

#### EVT_SEL Register (Offset 0x04)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [2:0] | `SEL` | R/W | 0 | **Event Select.** Selects which of 8 hardware events to count. See Section 4. |
| [31:3] | — | RO | 0 | Reserved |

#### COUNT Register (Offset 0x08)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `COUNT` | RO | 0 | Current 32-bit event count. Saturates at `0xFFFF_FFFF` and sets OVERFLOW. |

#### THRESH Register (Offset 0x0C)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [31:0] | `THRESH` | R/W | `0xFFFF_FFFF` | **Threshold value.** When `COUNT >= THRESH`, THRESH_HIT is set in STATUS and (if IRQ_EN=1) `irq_o` is asserted. Reset to max to prevent spurious interrupts. |

#### STATUS Register (Offset 0x10) — W1C

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `OVERFLOW` | R/W1C | 0 | **Sticky Overflow.** Set when COUNT reaches `0xFFFF_FFFF`. Cleared by writing 1 to this bit (Write-1-to-Clear). |
| [1] | `THRESH_HIT` | R/W1C | 0 | **Threshold Hit.** Set when `COUNT >= THRESH`. Cleared by writing 1 to this bit (Write-1-to-Clear). |
| [31:2] | — | RO | 0 | Reserved |

> [!IMPORTANT]
> **W1C (Write-1-to-Clear) semantics:** Writing a 0 to a W1C bit has no effect. Only writing a 1 clears the bit. This prevents race conditions when the interrupt handler reads the status and clears only the bits it has processed.

---

### 3.4 UART — Base Address `0x0000_2000`

16550-subset UART with 16-entry TX and RX FIFOs.

| Absolute Addr | Offset | Register | Access | Reset | Description |
|---|---|---|---|---|---|
| `0x0000_2000` | `0x00` | `RBR` (read) / `THR` (write) | R / W | — | **Receive Buffer / Transmit Holding.** Read to receive a byte; write to transmit a byte. |
| `0x0000_2004` | `0x04` | `IER` | R/W | `0x00` | **Interrupt Enable Register.** Bit[0]=RX data available; Bit[1]=TX empty |
| `0x0000_2008` | `0x08` | `DIVISOR` | R/W | `0x0000` | **Baud Rate Divisor** (16-bit). Baud = `f_clk / (16 × DIVISOR)` |
| `0x0000_200C` | `0x0C` | `LCR` | R/W | `0x03` | **Line Control Register.** Bits[1:0]=data bits (11=8); Bit[2]=stop bits; Bit[3]=parity |
| `0x0000_2010` | `0x10` | `LSR` | RO | `0x60` | **Line Status Register.** Bit[0]=RX data ready; Bit[5]=TX holding empty; Bit[6]=TX empty |

#### Baud Rate Examples (50 MHz Clock)

| Baud Rate | DIVISOR Value | Actual Baud | Error |
|---|---|---|---|
| 9600 | 325 | 9,615 | 0.16% |
| 115200 | 27 | 115,741 | 0.47% |
| 230400 | 14 | 223,214 | 3.1% |
| 1000000 | 3 | 1,041,667 | 4.2% |

---

### 3.5 Timer — Base Address `0x0000_2100`

32-bit down-counting timer with auto-reload and single-cycle interrupt pulse.

| Absolute Addr | Offset | Register | Access | Reset | Description |
|---|---|---|---|---|---|
| `0x0000_2100` | `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register |
| `0x0000_2104` | `0x04` | `RELOAD` | R/W | `0xFFFF_FFFF` | Reload value (loaded when timer expires or is disabled) |
| `0x0000_2108` | `0x08` | `COUNT` | RO | `0xFFFF_FFFF` | Current down-count value |

#### CTRL Register (Offset 0x00)

| Bits | Field | Access | Reset | Description |
|---|---|---|---|---|
| [0] | `EN` | R/W | 0 | **Timer Enable.** 1 = count down; 0 = frozen, COUNT held at RELOAD |
| [1] | `AUTO_RELOAD` | R/W | 0 | **Auto-reload.** 1 = reload from RELOAD register when COUNT hits 0; 0 = hold at 0 |
| [2] | `IRQ_EN` | R/W | 0 | **Interrupt Enable.** 1 = generate `timer_int` pulse when COUNT hits 0 |
| [31:3] | — | RO | 0 | Reserved |

---

### 3.6 GPIO — Base Address `0x0000_2200`

8-bit bidirectional GPIO with per-bit direction control.

| Absolute Addr | Offset | Register | Access | Reset | Description |
|---|---|---|---|---|---|
| `0x0000_2200` | `0x00` | `DIR` | R/W | `0x00` | **Direction.** Bit=1: pin is output; Bit=0: pin is input (high-Z) |
| `0x0000_2204` | `0x04` | `OUT` | R/W | `0x00` | **Output Data.** Value driven on pins configured as output (DIR=1) |
| `0x0000_2208` | `0x08` | `IN` | RO | — | **Input Data.** Sampled pin state (all pins regardless of direction) |

GPIO Register Fields (all registers use bits [7:0] only; bits [31:8] are reserved):

| Bits | Description |
|---|---|
| [7:0] | Per-pin value. Bit 0 = GPIO[0], …, Bit 7 = GPIO[7] |
| [31:8] | Reserved, read as 0 |

---

## 4. Performance Event Select Table

The Event Counter's `EVT_SEL.SEL` field (bits [2:0]) selects which hardware event increments the counter:

| EVT_SEL Value | Event Name | RTL Signal | Signal Source | Firmware Stimulus |
|---|---|---|---|---|
| `3'd0` | `BRANCH_TAKEN` | `branch_taken` | VeeR EL2 execute stage | Loop with always-taken backward branch |
| `3'd1` | `BRANCH_ANY` | `branch_any` | VeeR EL2 decode stage | Mix of `beq`, `bne`, `jal`, `jalr` |
| `3'd2` | `ALU_OP` | `alu_op` | VeeR EL2 execute stage | Sequence of `add`, `sub`, `and`, `xor` |
| `3'd3` | `LOAD_OP` | `load_op` | VeeR EL2 LSU | Sequential array read loop (`lw`) |
| `3'd4` | `STORE_OP` | `store_op` | VeeR EL2 LSU | Sequential array write loop (`sw`) |
| `3'd5` | `STALL_CYCLE` | `stall_cycle` | VeeR EL2 pipeline | RAW data hazard: produce then immediately consume |
| `3'd6` | `IFU_MISS` | `ifu_miss` | VeeR EL2 IFU | Non-sequential instruction flow (many jumps) |
| `3'd7` | `RETIRE_VALID` | `retire_valid` | VeeR EL2 commit stage | Any executing code (equivalent to instruction counter) |

### 4.1 Firmware Event Selection Examples

```c
#include "perf_regs.h"

// Count branch-taken events
void measure_branches(void) {
    *EVENT_CTRL   = 0;             // disable
    *EVENT_EVT_SEL = EVT_BRANCH_TAKEN;  // EVT_SEL = 0
    *EVENT_COUNT  = 0;             // read-only, use CLR bit
    *CTRL_REG    |= CTRL_CLR;      // clear counter
    *EVENT_THRESH = 10000;         // interrupt after 10,000 branches
    *EVENT_CTRL   = CTRL_EN | CTRL_IRQ_EN;

    // ... run test code ...

    *EVENT_CTRL   = 0;             // stop
    uint32_t branch_count = *EVENT_COUNT;
}
```

---

## 5. Bus Error Behaviour

When the bus decoder receives an access to an unmapped address:

| Scenario | Bus Response | Software Effect |
|---|---|---|
| Unmapped peripheral (addr[11:8] ≥ 6) in page 2 | `error=1`, `ready=1`, `rdata=0xDEAD_BEEF` | AHB-Lite: HRESP = ERROR, two-cycle error |
| Unmapped page (addr[31:12] ≥ 3) | `error=1`, `ready=1`, `rdata=0xDEAD_BEEF` | Same |
| Write to unmapped address | `error=1`, write silently discarded | Same |

On the VeeR EL2, an AHB-Lite HRESP=ERROR response generates an **imprecise bus fault** exception (or causes the core to stall / trap, depending on configuration). In the testbench, the passive UART monitor and self-checking assertions treat any access returning `0xDEAD_BEEF` as a test failure.

---

## 6. Shadow Register Protocol

### 6.1 Why a Shadow Register Is Necessary

The 64-bit counters are wider than the 32-bit data bus. Without a snapshot mechanism, reading CNT_LO and then CNT_HI risks reading two inconsistent halves if the counter crosses a 32-bit boundary between the two reads.

**Without shadow registers (incorrect):**
```
T0: Read CNT_LO → returns 0xFFFF_FFFE  (counter = 0x0000_0001_FFFF_FFFE)
    Counter ticks → becomes 0x0000_0002_0000_0000
T1: Read CNT_HI → returns 0x0000_0002
Result: 0x0000_0002_FFFF_FFFE  ← WRONG (overflow not captured)
```

**With shadow registers (correct):**
```
T0: Read CNT_LO → returns 0xFFFF_FFFE
    Hardware simultaneously captures CNT_HI = 0x0000_0001 into shadow_hi
    Counter ticks → becomes 0x0000_0002_0000_0000
T1: Read CNT_HI → returns shadow_hi = 0x0000_0001
Result: 0x0000_0001_FFFF_FFFE  ← CORRECT (matches moment of CNT_LO read)
```

### 6.2 Mandatory Read Order

> [!CAUTION]
> **Always read CNT_LO before CNT_HI.** Reading CNT_HI without first reading CNT_LO returns stale shadow data from the previous read sequence.

### 6.3 Coherent 64-bit Read Procedure

```c
// Correct 64-bit counter read sequence
uint64_t read_cycle_counter(void) {
    uint32_t lo = *CYCLE_CNT_LO;    // Step 1: Read LO → triggers shadow latch
    uint32_t hi = *CYCLE_CNT_HI;    // Step 2: Read HI → returns latched shadow
    return ((uint64_t)hi << 32) | lo;
}

// WRONG: Do NOT read HI first
uint64_t read_cycle_counter_WRONG(void) {
    uint32_t hi = *CYCLE_CNT_HI;    // Returns stale shadow
    uint32_t lo = *CYCLE_CNT_LO;    // Triggers latch (too late)
    return ((uint64_t)hi << 32) | lo;  // hi is from previous read!
}
```

### 6.4 RTL Implementation of the Latch

```verilog
// In cycle_cnt_top.v
reg [31:0] shadow_hi;

wire rd_cnt_lo = sel & ren & (addr[7:2] == 6'd2);  // offset 0x08

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        shadow_hi <= 32'h0;
    else if (rd_cnt_lo)
        shadow_hi <= cnt_hi_int;  // Latch current HI when LO is read
end

// Register read mux
always @(*) begin
    case (addr[7:2])
        6'd0: rdata = ctrl_reg;
        6'd1: rdata = status_reg;
        6'd2: rdata = cnt_lo_int;    // Returns live LO
        6'd3: rdata = shadow_hi;     // Returns latched HI
        default: rdata = 32'h0;
    endcase
end
```

---

## 7. C Header Definitions (`perf_regs.h`)

The following reproduces the key `#define` lines from the project's `sw/include/perf_regs.h`:

```c
/* perf_regs.h
 * Register address definitions for the RISC-V HPM SoC
 * Student ID: 1602-23-735-108
 */

#ifndef PERF_REGS_H
#define PERF_REGS_H

#include <stdint.h>

/* ================================================================
 * Base Addresses
 * ================================================================ */
#define UART_BASE       0x00002000U
#define TIMER_BASE      0x00002100U
#define GPIO_BASE       0x00002200U
#define CYCLE_CNT_BASE  0x00002300U
#define INSTR_CNT_BASE  0x00002400U
#define EVENT_CNT_BASE  0x00002500U

/* ================================================================
 * Register Access Macros
 * ================================================================ */
#define REG32(base, offset)  (*((volatile uint32_t *)((base) + (offset))))

/* ================================================================
 * Cycle Counter Registers
 * ================================================================ */
#define CYCLE_CTRL      REG32(CYCLE_CNT_BASE, 0x00)
#define CYCLE_STATUS    REG32(CYCLE_CNT_BASE, 0x04)
#define CYCLE_CNT_LO    REG32(CYCLE_CNT_BASE, 0x08)
#define CYCLE_CNT_HI    REG32(CYCLE_CNT_BASE, 0x0C)

/* ================================================================
 * Instruction Counter Registers
 * ================================================================ */
#define INSTR_CTRL      REG32(INSTR_CNT_BASE, 0x00)
#define INSTR_STATUS    REG32(INSTR_CNT_BASE, 0x04)
#define INSTR_CNT_LO    REG32(INSTR_CNT_BASE, 0x08)
#define INSTR_CNT_HI    REG32(INSTR_CNT_BASE, 0x0C)

/* ================================================================
 * Performance Event Counter Registers
 * ================================================================ */
#define EVENT_CTRL      REG32(EVENT_CNT_BASE, 0x00)
#define EVENT_SEL       REG32(EVENT_CNT_BASE, 0x04)
#define EVENT_COUNT     REG32(EVENT_CNT_BASE, 0x08)
#define EVENT_THRESH    REG32(EVENT_CNT_BASE, 0x0C)
#define EVENT_STATUS    REG32(EVENT_CNT_BASE, 0x10)

/* ================================================================
 * UART Registers
 * ================================================================ */
#define UART_RBR_THR    REG32(UART_BASE, 0x00)
#define UART_IER        REG32(UART_BASE, 0x04)
#define UART_DIVISOR    REG32(UART_BASE, 0x08)
#define UART_LCR        REG32(UART_BASE, 0x0C)
#define UART_LSR        REG32(UART_BASE, 0x10)

/* ================================================================
 * Timer Registers
 * ================================================================ */
#define TIMER_CTRL      REG32(TIMER_BASE, 0x00)
#define TIMER_RELOAD    REG32(TIMER_BASE, 0x04)
#define TIMER_COUNT     REG32(TIMER_BASE, 0x08)

/* ================================================================
 * GPIO Registers
 * ================================================================ */
#define GPIO_DIR        REG32(GPIO_BASE, 0x00)
#define GPIO_OUT        REG32(GPIO_BASE, 0x04)
#define GPIO_IN         REG32(GPIO_BASE, 0x08)

/* ================================================================
 * CTRL Register Bit Fields (shared across HPM IPs)
 * ================================================================ */
#define CTRL_EN         (1U << 0)   /* Counter enable */
#define CTRL_CLR        (1U << 1)   /* Counter clear (self-clearing) */
#define CTRL_IRQ_EN     (1U << 2)   /* Interrupt enable (Event Counter only) */

/* ================================================================
 * Event Counter EVT_SEL Values
 * ================================================================ */
#define EVT_BRANCH_TAKEN  0U    /* Conditional branch resolved taken */
#define EVT_BRANCH_ANY    1U    /* Any branch instruction */
#define EVT_ALU_OP        2U    /* ALU operation */
#define EVT_LOAD_OP       3U    /* Load instruction */
#define EVT_STORE_OP      4U    /* Store instruction */
#define EVT_STALL_CYCLE   5U    /* Pipeline stall cycle */
#define EVT_IFU_MISS      6U    /* IFU fetch miss / wait */
#define EVT_RETIRE_VALID  7U    /* Instruction retirement (alias) */

/* ================================================================
 * Event Counter STATUS Bit Fields (W1C)
 * ================================================================ */
#define STATUS_OVERFLOW     (1U << 0)   /* Sticky overflow flag */
#define STATUS_THRESH_HIT   (1U << 1)   /* Threshold hit flag */

/* ================================================================
 * UART LSR Bit Fields
 * ================================================================ */
#define UART_LSR_DR         (1U << 0)   /* Data ready (RX) */
#define UART_LSR_THRE       (1U << 5)   /* TX holding register empty */
#define UART_LSR_TEMT       (1U << 6)   /* TX completely empty */

/* ================================================================
 * Timer CTRL Bit Fields
 * ================================================================ */
#define TIMER_CTRL_EN           (1U << 0)
#define TIMER_CTRL_AUTO_RELOAD  (1U << 1)
#define TIMER_CTRL_IRQ_EN       (1U << 2)

/* ================================================================
 * GPIO DIR Bit Fields
 * ================================================================ */
#define GPIO_OUTPUT     1U   /* Bit value for output direction */
#define GPIO_INPUT      0U   /* Bit value for input direction */

/* ================================================================
 * Helper: Coherent 64-bit counter read
 * ================================================================ */
static inline uint64_t read_cycle_count(void) {
    uint32_t lo = CYCLE_CNT_LO;   /* Latches shadow HI */
    uint32_t hi = CYCLE_CNT_HI;   /* Reads shadow HI */
    return ((uint64_t)hi << 32) | (uint64_t)lo;
}

static inline uint64_t read_instr_count(void) {
    uint32_t lo = INSTR_CNT_LO;
    uint32_t hi = INSTR_CNT_HI;
    return ((uint64_t)hi << 32) | (uint64_t)lo;
}

#endif /* PERF_REGS_H */
```

---

## 8. Address Map Quick Reference Card

```
Physical Address Space – RISC-V HPM SoC
─────────────────────────────────────────────────────────────
0x0000_0000 ┌─────────────────────────────┐
            │  IMEM  (4 KB)               │  Instruction Memory
0x0000_0FFF └─────────────────────────────┘
0x0000_1000 ┌─────────────────────────────┐
            │  DMEM  (4 KB)               │  Data Memory + Stack
0x0000_1FFF └─────────────────────────────┘
0x0000_2000 ┌─────────────────────────────┐
            │  UART  (256 B)              │  RBR/THR, IER, DIVISOR, LCR, LSR
0x0000_20FF └─────────────────────────────┘
0x0000_2100 ┌─────────────────────────────┐
            │  Timer (256 B)              │  CTRL, RELOAD, COUNT
0x0000_21FF └─────────────────────────────┘
0x0000_2200 ┌─────────────────────────────┐
            │  GPIO  (256 B)              │  DIR, OUT, IN
0x0000_22FF └─────────────────────────────┘
0x0000_2300 ┌─────────────────────────────┐
            │  Cycle Counter (256 B)      │  CTRL, STATUS, CNT_LO, CNT_HI
0x0000_23FF └─────────────────────────────┘
0x0000_2400 ┌─────────────────────────────┐
            │  Instr Counter (256 B)      │  CTRL, STATUS, CNT_LO, CNT_HI
0x0000_24FF └─────────────────────────────┘
0x0000_2500 ┌─────────────────────────────┐
            │  Event Counter (256 B)      │  CTRL, EVT_SEL, COUNT, THRESH, STATUS
0x0000_25FF └─────────────────────────────┘
0x0000_2600 ┌─────────────────────────────┐
            │  UNMAPPED  (bus error)      │
0xFFFF_FFFF └─────────────────────────────┘
```

---

*End of Address Map Specification*
