# SoC Memory Map Specification

This document defines the system physical address layout decoded by `rtl/interconnect/bus_decoder.v`.

---

## 1. Physical Memory Map

| Address Range | Size | Module | Description | Offset Seen by IP |
|---------------|------|--------|-------------|-------------------|
| `0x0000_0000 – 0x0000_0FFF` | 4 KB | Instruction Memory (IMEM) | Program instruction storage (`imem.v`) | `addr[11:0]` |
| `0x0000_1000 – 0x0000_1FFF` | 4 KB | Data Memory (DMEM) | Data RAM (`dmem.v`) | `addr[11:0]` |
| `0x0000_2000 – 0x0000_20FF` | 256 B | UART | 16550-compatible serial UART (`uart_top.v`) | `addr[7:0]` |
| `0x0000_2100 – 0x0000_21FF` | 256 B | Timer | 32-bit Reloadable Down-Counter (`timer_top.v`) | `addr[7:0]` |
| `0x0000_2200 – 0x0000_22FF` | 256 B | GPIO | 8-bit GPIO Controller (`gpio_top.v`) | `addr[7:0]` |
| `0x0000_2300 – 0x0000_23FF` | 256 B | Cycle Counter | 64-bit Cycle Counter IP (`cycle_cnt_top.v`) | `addr[7:0]` |
| `0x0000_2400 – 0x0000_24FF` | 256 B | Instruction Counter | 64-bit Instruction Counter IP (`instr_cnt_top.v`) | `addr[7:0]` |
| `0x0000_2500 – 0x0000_25FF` | 256 B | Performance Event Counter | 32-bit Event Counter IP (`event_cnt_top.v`) | `addr[7:0]` |

---

## 2. Address Decoding Rules

1. **Peripherals**:
   - Reside in the page `0x0000_2xxx` (`addr[31:12] == 20'h00002`).
   - Selected by nibble `addr[11:8]` (`0x0` to `0x5`).
   - Each peripheral sees only its internal byte offset `addr[7:0]`.
2. **Memories**:
   - `0x0000_0xxx` selects IMEM (4 KB window).
   - `0x0000_1xxx` selects DMEM (4 KB window).
   - Memories receive 12-bit offset `addr[11:0]`.
3. **Unmapped Address Handling**:
   - Any transaction to addresses outside these designated windows (e.g. `0x0000_2600` through `0xFFFF_FFFF`) completes in 1 cycle with:
     - `m_ready_o = 1`
     - `m_rdata_o = 32'h0000_0000`
     - `m_err_o   = 1`
   - Unmapped accesses never hang the system bus or processor core.
