# Verification Plan and Test Matrix

This document defines the verification strategy, test coverage matrix, and testbench implementations for the RISC-V Hardware Performance Monitoring SoC.

---

## 1. Verification Strategy

The verification environment uses self-checking, deterministic Verilog testbenches:
1. **IP Unit Verification**: Individual testbenches drive each IP via Bus Functional Model (`bus_bfm.v`) tasks simulating system bus transactions. Tests check reset states, normal operation, boundary conditions, priority cases, carry propagation, and illegal accesses.
2. **Interconnect Verification**: Checks address decoder window boundaries, one-hot selection, and non-blocking error responses for unmapped space.
3. **SoC Integration Verification**: Simulates the top-level SoC with processor core, memories, peripherals, and performance monitors. Uses passive UART monitoring, GPIO indicators, and hierarchical cross-checks comparing DUT counters against independent testbench shadow counters.

---

## 2. Test Coverage Matrix

### 2.1 Cycle Counter (`tb_cycle_cnt.v`)

| Test Case | Description | Verification Check |
|-----------|-------------|--------------------|
| `TC_CYC_01` | Reset Defaults | Verify `CTRL=0`, `STATUS=0`, `CNT_LO=0`, `CNT_HI=0`, `bus_err=0`. |
| `TC_CYC_02` | Disabled Hold | Clock runs with `EN=0`; verify `CNT_LO` does not increment. |
| `TC_CYC_03` | Enable & Count | Write `EN=1`; verify `STATUS.RUNNING=1` and `CNT_LO` increments every cycle. |
| `TC_CYC_04` | Disable Hold | Set `EN=0`; verify count freezes at current value over multiple cycles. |
| `TC_CYC_05` | CLEAR Priority | Simultaneously write `EN=1` and `CLEAR=1`; verify count clears to 0 (priority over count). |
| `TC_CYC_06` | Coherent 64-bit Read | Read `CNT_LO` while running; verify `CNT_HI` reflects shadow value captured during `CNT_LO` read despite ongoing increments. |
| `TC_CYC_07` | Carry into CNT_HI | Preload count to `0x0000_0000_FFFF_FFFE`; advance count; verify carry into `CNT_HI=1`. |
| `TC_CYC_08` | RO Register Writes | Write to `STATUS`, `CNT_LO`, `CNT_HI`; verify transaction completes with `bus_err=0` and values are unaffected. |
| `TC_CYC_09` | Undefined Offsets | Access offsets `0x10`, `0x14`, `0x20`; verify `bus_err=1`. |

### 2.2 Instruction Counter (`tb_instr_cnt.v`)

| Test Case | Description | Verification Check |
|-----------|-------------|--------------------|
| `TC_INS_01` | Reset Defaults | Verify `CTRL=0`, `STATUS=0`, `CNT_LO=0`, `CNT_HI=0`. |
| `TC_INS_02` | Inactive Hold | Pulse `instr_retire_i` while `EN=0`; verify count does not advance. |
| `TC_INS_03` | Idle Cycles Ignored | Set `EN=1` with `instr_retire_i=0`; verify count does not advance. |
| `TC_INS_04` | Accurate Retirement Count | Pulse `instr_retire_i` exactly 10 times; verify `CNT_LO == 10`. |
| `TC_INS_05` | CLEAR Priority | Assert `instr_retire_i` and write `CLEAR=1`; verify count resets to 0. |
| `TC_INS_06` | Coherent 64-bit Read | Read `CNT_LO` then retire 20 instructions; verify `CNT_HI` returns coherent captured shadow value. |
| `TC_INS_07` | 64-bit Carry | Preload count to `0x0000_0000_FFFF_FFFF`; pulse retirement; verify `CNT_LO=0` and `CNT_HI=1`. |
| `TC_INS_08` | RO Register Writes | Writes to `STATUS`, `CNT_LO`, `CNT_HI` are ignored with `bus_err=0`. |
| `TC_INS_09` | Undefined Offsets | Access undefined offsets; verify `bus_err=1`. |

### 2.3 Performance Event Counter (`tb_event_cnt.v`)

| Test Case | Description | Verification Check |
|-----------|-------------|--------------------|
| `TC_EVT_01` | Reset Defaults | Verify `CTRL=0`, `EVT_SEL=0`, `COUNT=0`, `THRESH=0`, `STATUS=0`, `irq_o=0`. |
| `TC_EVT_02` | 8 Event Isolation | For each event `0..7`: select event, pulse other 7 events (verify no increment), then pulse selected event (verify count + 1). |
| `TC_EVT_03` | Threshold & Re-arm | Set `THRESH=4`; pulse 3 events (no flag); 4th pulse sets `THRESH_HIT=1`. Clear via W1C; 5th pulse re-arms flag to 1. |
| `TC_EVT_04` | Event vs W1C Priority | Simultaneously assert W1C clear and event pulse; verify new event wins and `THRESH_HIT` remains 1. |
| `TC_EVT_05` | Overflow Flag (OVF) | Preload `0xFFFFFFFF`; pulse event; verify wrap to 0 and `OVF=1`. Verify W1C clears `OVF`. |
| `TC_EVT_06` | IRQ Gating | With `THRESH_HIT=1`: verify `irq_o=0` when `IRQ_EN=0`, and `irq_o=1` when `IRQ_EN=1`. |
| `TC_EVT_07` | Global CLEAR | When count > 0, `OVF=1`, `THRESH_HIT=1`: write `CLEAR=1`; verify count, `OVF`, and `THRESH_HIT` all clear to 0. |
| `TC_EVT_08` | Zero Threshold | Set `THRESH=0`; count 10 events; verify `THRESH_HIT` never asserts. |
| `TC_EVT_09` | RO Register & Offset Errors | Write to `COUNT` ignored; undefined offset returns `bus_err=1`. |

### 2.4 Address Decoder (`tb_bus_decoder.v`)

| Test Case | Description | Verification Check |
|-----------|-------------|--------------------|
| `TC_DEC_01` | IMEM Boundaries | Access `0x0000_0000` and `0x0000_0FFF`; verify only IMEM selected. |
| `TC_DEC_02` | DMEM Boundaries | Access `0x0000_1000` and `0x0000_1FFF`; verify only DMEM selected. |
| `TC_DEC_03` | Peripheral Boundaries | Verify first and last addresses for UART, Timer, GPIO, Cycle Cnt, Instr Cnt, Event Cnt; check one-hot selection and `addr[7:0]` offset mapping. |
| `TC_DEC_04` | Unmapped Space | Access `0x0000_2600`, `0x0000_3000`, `0x1000_0000`; verify `m_ready=1`, `m_rdata=0`, `m_err=1` without hanging. |

### 2.5 SoC Top (`tb_soc_top.v`)

| Test Case | Description | Verification Check |
|-----------|-------------|--------------------|
| `TC_SOC_01` | Power-on Reset | CPU boots from `0x0000_0000`. |
| `TC_SOC_02` | UART String Monitor | Monitors serial output; triggers on `"PASS"` or `"FAIL"`. |
| `TC_SOC_03` | Architectural Cross-Checks | Verifies `DUT_cycles >= DUT_instructions > 0`; verifies DUT counters match TB shadow counters. |
| `TC_SOC_04` | Watchdog Protection | Enforces timeout to catch runaway code. |
