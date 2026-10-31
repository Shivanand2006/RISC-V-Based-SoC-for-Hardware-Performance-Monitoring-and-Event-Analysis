# SoC Peripheral Register Map Specification

This document details the register definitions, bit fields, reset values, and access permissions for all memory-mapped peripherals and hardware performance monitors.

---

## 1. Cycle Counter (`0x0000_2300`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register.<br>- Bit `0`: `EN` (1 = counting enabled, 0 = disabled)<br>- Bit `1`: `CLEAR` (Write 1 = clears 64-bit count to 0; self-clearing, reads as 0)<br>- Bits `[31:2]`: Reserved (read as 0) |
| `0x04` | `STATUS` | RO | `0x0000_0000` | Status register.<br>- Bit `0`: `RUNNING` (mirrors `EN`)<br>- Bits `[31:1]`: Reserved (read as 0) |
| `0x08` | `CNT_LO` | RO | `0x0000_0000` | Low 32 bits of 64-bit cycle count (`count[31:0]`).<br>**Read Side-Effect**: Reading `CNT_LO` captures `count[63:32]` into the internal `CNT_HI` shadow register in the same clock cycle. |
| `0x0C` | `CNT_HI` | RO | `0x0000_0000` | Shadow register containing `count[63:32]` captured during the last `CNT_LO` read. |

---

## 2. Instruction Counter (`0x0000_2400`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register.<br>- Bit `0`: `EN` (1 = counting enabled, 0 = disabled)<br>- Bit `1`: `CLEAR` (Write 1 = clears 64-bit count to 0; self-clearing, reads as 0)<br>- Bits `[31:2]`: Reserved |
| `0x04` | `STATUS` | RO | `0x0000_0000` | Status register.<br>- Bit `0`: `RUNNING` (mirrors `EN`)<br>- Bits `[31:1]`: Reserved |
| `0x08` | `CNT_LO` | RO | `0x0000_0000` | Low 32 bits of 64-bit retired instruction count (`count[31:0]`).<br>**Read Side-Effect**: Reading `CNT_LO` captures `count[63:32]` into `CNT_HI` shadow register. |
| `0x0C` | `CNT_HI` | RO | `0x0000_0000` | Shadow register containing `count[63:32]` captured during the last `CNT_LO` read. |

---

## 3. Performance Event Counter (`0x0000_2500`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register.<br>- Bit `0`: `EN` (1 = counting enabled)<br>- Bit `1`: `CLEAR` (Write 1 = clears `COUNT`, `OVF`, and `THRESH_HIT`; self-clearing, reads 0)<br>- Bit `2`: `IRQ_EN` (1 = enable threshold interrupt output `irq_o`)<br>- Bits `[31:3]`: Reserved |
| `0x04` | `EVT_SEL` | R/W | `0x0000_0000` | Event select register.<br>- Bits `[2:0]`: Selected event index (0–7)<br>- Bits `[31:3]`: Reserved |
| `0x08` | `COUNT` | RO | `0x0000_0000` | 32-bit accumulated event count. |
| `0x0C` | `THRESH` | R/W | `0x0000_0000` | 32-bit threshold. When non-zero, triggers `THRESH_HIT` when `COUNT >= THRESH`. Value `0` disables threshold compare. |
| `0x10` | `STATUS` | R/W1C | `0x0000_0000` | Status register.<br>- Bit `0`: `OVF` (sticky wrap past `0xFFFFFFFF`; write 1 to clear)<br>- Bit `1`: `THRESH_HIT` (sticky; write 1 to clear; re-arms on next counted event)<br>- Bit `2`: `RUNNING` (RO, mirrors `EN`)<br>- Bits `[31:3]`: Reserved |

### Event Select Encoding (`EVT_SEL[2:0]`):
- `0`: Data memory read accepted (Load)
- `1`: Data memory write accepted (Store)
- `2`: Instruction fetch accepted
- `3`: Branch or Jump taken
- `4`: Pipeline stall or memory wait cycle
- `5`: Exception / Trap taken
- `6`: Hardware Timer interrupt event (`tick_o`)
- `7`: UART Transmit complete event (`tx_done_o`)

---

## 4. UART Peripheral (`0x0000_2000`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `RBR_THR` | R/W | `0x0000_0000` | RBR (Read Only): Received byte.<br>THR (Write Only): Transmit holding byte. |
| `0x04` | `IER` | R/W | `0x0000_0000` | Interrupt Enable Register.<br>- Bit `0`: Rx Data Ready interrupt enable<br>- Bit `1`: Tx Holding Register Empty interrupt enable |
| `0x08` | `DIVISOR` | R/W | `16'd434` | Baud divisor register (115200 baud default at 50MHz). |
| `0x0C` | `LCR` | R/W | `0x0000_0003` | Line Control Register (8N1 default). |
| `0x14` | `LSR` | RO | `0x0000_0060` | Line Status Register.<br>- Bit `0`: `DATA_READY`<br>- Bit `5`: `THRE` (Transmit Holding Register Empty)<br>- Bit `6`: `TEMT` (Transmitter Empty) |

---

## 5. Timer Peripheral (`0x0000_2100`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `CTRL` | R/W | `0x0000_0000` | Control register.<br>- Bit `0`: `EN` (1 = timer running) |
| `0x04` | `RELOAD` | R/W | `0x0000_0000` | 32-bit counter reload value. |
| `0x08` | `COUNT` | RO | `0x0000_0000` | 32-bit down-counter current value. Pulses `tick_o` for 1 cycle when reaching zero and reloads. |

---

## 6. GPIO Peripheral (`0x0000_2200`)

| Offset | Register | Access | Reset | Description |
|--------|----------|--------|-------|-------------|
| `0x00` | `DIR` | R/W | `0x0000_0000` | 8-bit direction register (1 = output, 0 = input). |
| `0x04` | `OUT` | R/W | `0x0000_0000` | 8-bit output data register. Drives `gpio_out = OUT & DIR`. |
| `0x08` | `IN` | RO | `0x0000_0000` | 8-bit input data register (synchronized through 2 flip-flops from `gpio_in`). |
