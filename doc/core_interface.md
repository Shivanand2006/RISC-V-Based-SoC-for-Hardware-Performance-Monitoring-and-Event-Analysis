# RISC-V Core Interface Specification (CHIPS Alliance VeeR EL2)

This document details the interface, bus protocols, timing specifications, and hardware event observation signals for the **CHIPS Alliance VeeR EL2 Core** ([`Cores-VeeR-EL2`](file:///home/student/1602-23-735-108/Cores-VeeR-EL2/design/el2_veer_wrapper.sv)) integrated into the hardware performance monitoring SoC via [`veer_core_adapter.sv`](file:///home/student/1602-23-735-108/rtl/core/veer_core_adapter.sv).

---

## 1. Core Profile & Configuration

- **Core**: CHIPS Alliance / Western Digital VeeR EL2 (4-stage superscalar / single-issue RV32IMC core).
- **Target Configuration**: `default_ahb` generated via `configs/veer.config -target=default_ahb`.
- **Clock**: `clk` (active rising edge).
- **Reset**: `rst_l` and `dbg_rst_l` (active-low asynchronous reset).
- **Reset Vector**: `rst_vec[31:1] = 31'h0000_0000` (Core begins instruction fetch at `0x0000_0000` mapped to IMEM).

---

## 2. Bus Protocols & Interfaces

### 2.1 Load/Store Unit (LSU) Master Bus Interface (Data Bus)
The VeeR EL2 LSU acts as an **AHB-Lite Master** generating data reads and writes:

| Signal Name | Direction | Width | Protocol & Timing |
|-------------|-----------|-------|-------------------|
| `lsu_haddr` | Output | 32 bits | Memory transfer byte address driven during the address phase. |
| `lsu_htrans`| Output | 2 bits | Transfer type: `2'b00` (IDLE), `2'b10` (NONSEQ), `2'b11` (SEQ). |
| `lsu_hwrite`| Output | 1 bit | 1 = Write transaction (Store); 0 = Read transaction (Load). |
| `lsu_hsize` | Output | 3 bits | Transfer size: `0` = Byte, `1` = Halfword, `2` = Word (32-bit), `3` = Doubleword (64-bit). |
| `lsu_hwdata`| Output | 64 bits | Write data driven during the data phase. |
| `lsu_hrdata`| Input | 64 bits | Read data returned by the slave during the data phase. |
| `lsu_hready`| Input | 1 bit | Slave handshake ready signal. When 0, inserts wait states. |
| `lsu_hresp` | Input | 1 bit | Transfer response: 0 = OKAY, 1 = ERROR. |

**Bus Adapter**: Adapted to the 32-bit single-cycle system bus by [`ahb_to_bus_adapter.v`](file:///home/student/1602-23-735-108/rtl/core/ahb_to_bus_adapter.v), which bridges AHB-Lite to the central [`bus_decoder.v`](file:///home/student/1602-23-735-108/rtl/interconnect/bus_decoder.v).

### 2.2 Instruction Fetch Unit (IFU) Master Bus Interface
The VeeR EL2 IFU issues instruction fetch requests over a dedicated AHB-Lite bus:

| Signal Name | Direction | Width | Protocol & Timing |
|-------------|-----------|-------|-------------------|
| `haddr` | Output | 32 bits | Instruction fetch address driven during address phase. |
| `htrans`| Output | 2 bits | Transfer type (`2'b10` = active fetch). |
| `hwrite`| Output | 1 bit | Always `1'b0` (read-only instruction fetch). |
| `hrdata`| Input | 64 bits | 64-bit aligned instruction packet returned from IMEM. |
| `hready`| Input | 1 bit | Memory ready signal. Completes fetch in 1 cycle. |
| `hresp` | Input | 1 bit | Error response (tied to `0` for valid memory range). |

**Fetch Adapter**: Adapted to [`imem.v`](file:///home/student/1602-23-735-108/rtl/mem/imem.v) through [`ahb_imem_adapter.v`](file:///home/student/1602-23-735-108/rtl/core/ahb_imem_adapter.v).

---

## 3. Interrupt Signals

| Signal Name | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `timer_int` | Input | 1 bit | Level/pulse timer interrupt input wired directly to Timer peripheral `tick_o`. Triggers Machine Timer Interrupt (`MCAUSE = 0x8000_0007`). |
| `extintsrc_req`| Input | `pt.PIC_TOTAL_INT` bits | External interrupt lines connected to VeeR programmable interrupt controller (PIC). Bit 1 is wired to Performance Event Counter `irq_o`. |
| `soft_int` | Input | 1 bit | Software interrupt line (tied to `1'b0`). |

---

## 4. Instruction Retirement Signal

| Signal Name | File Location | Description & Timing |
|-------------|---------------|----------------------|
| `trace_rv_i_valid_ip` | `el2_veer_wrapper.sv` (line 50) | 1-cycle active-high pulse asserted when an instruction reaches the commit stage and successfully writes back to the architectural register state. |
| `instr_retire_o` | `veer_core_adapter.sv` | Derived as `trace_rv_i_valid_ip & ~trace_rv_i_exception_ip`. Pulses for exactly 1 cycle per retired instruction, excluding trapped or flushed instructions. Directly drives the 64-bit Instruction Counter IP. |

---

## 5. Performance Event Observation Signals

The 8 hardware events defined in Section 5.3 of the specification are mapped to real VeeR EL2 boundary and internal signals:

| `EVT_SEL` | Event Name | VeeR EL2 Signal Source | Exact Logic / Mapping Rule |
|-----------|------------|------------------------|----------------------------|
| `0` | Data read accepted (Load) | LSU AHB Bus / PMU | `lsu_htrans[1] & ~lsu_hwrite & lsu_hready`<br>*(also matches PMU `MHPME_INST_LOAD`)* |
| `1` | Data write accepted (Store) | LSU AHB Bus / PMU | `lsu_htrans[1] & lsu_hwrite & lsu_hready`<br>*(also matches PMU `MHPME_INST_STORE`)* |
| `2` | Instruction fetch accepted | IFU AHB Bus / PMU | `ifu_htrans[1] & ifu_hready`<br>*(matches PMU `MHPME_IBUS_TRANS`)* |
| `3` | Branch / Jump taken | DEC TLU / EXU | `dec_tlu_perfcnt0`<br>*(tapped from VeeR commit-stage branch-taken signal `exu_pmu_i0_br_ataken & tlu_i0_commit_cmt`)* |
| `4` | Pipeline stall or bubble | Bus wait / DEC PMU | `(ifu_htrans[1] & ~ifu_hready) \| (lsu_htrans[1] & ~lsu_hready)`<br>*(or internal `dec_pmu_decode_stall \| ifu_pmu_fetch_stall`)* |
| `5` | Exception / Trap taken | Trace exception | `trace_rv_i_exception_ip`<br>*(pulses 1 cycle on ECALL, illegal instruction, or interrupt trap entry)* |
| `6` | Timer interrupt event | Timer IP | `timer_tick`<br>*(1-cycle pulse generated by Timer peripheral down-counter reaching zero)* |
| `7` | UART transmit complete | UART IP | `uart_tx_done`<br>*(1-cycle pulse generated by UART peripheral upon serial frame completion)* |
