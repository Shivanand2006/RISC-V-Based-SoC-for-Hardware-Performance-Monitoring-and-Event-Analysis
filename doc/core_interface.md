# RISC-V Core Interface Specification

This document details the interface, bus protocols, timing specifications, and hardware event observation signals implemented in the `riscv_core` module for hardware performance monitoring.

---

## 1. Clock, Reset, and Interrupt Signals

| Signal Name | Direction | Width | Description / Timing |
|-------------|-----------|-------|----------------------|
| `clk` | Input | 1 bit | System clock (rising edge active). |
| `rst_n` | Input | 1 bit | Active-low asynchronous system reset. |
| `timer_irq_i` | Input | 1 bit | Level/pulse input from Timer IP (`tick_o`). Directly generates Event 6 and triggers machine timer interrupt when enabled in `MIE` and `MSTATUS`. |
| `ext_irq_i` | Input | 1 bit | External interrupt from Performance Event Counter IP (`irq_o`). Triggers machine external interrupt when enabled. |
| `uart_irq_i` | Input | 1 bit | Peripheral interrupt from UART IP (`irq_o`). |

---

## 2. Instruction Fetch Interface (IMEM)

The core accesses instruction memory through a dedicated synchronous bus:

| Signal Name | Direction | Width | Protocol & Timing |
|-------------|-----------|-------|-------------------|
| `imem_req_o` | Output | 1 bit | High when the processor requests an instruction fetch. |
| `imem_addr_o` | Output | 32 bits | Byte address of instruction to fetch (PC, 4-byte aligned). |
| `imem_ready_i` | Input | 1 bit | Memory ready strobe. Completes fetch in 1 cycle. |
| `imem_rdata_i` | Input | 32 bits | Instruction word returned from memory array. |

---

## 3. Data Memory Bus Interface (DMEM / Interconnect)

The data bus connects the core master to the central `bus_decoder` interconnect:

| Signal Name | Direction | Width | Protocol & Timing |
|-------------|-----------|-------|-------------------|
| `dmem_req_o` | Output | 1 bit | Request strobe. Asserted when initiating load or store. |
| `dmem_we_o` | Output | 1 bit | 1 = write transaction (Store); 0 = read transaction (Load). |
| `dmem_addr_o` | Output | 32 bits | Target byte memory address. |
| `dmem_wdata_o` | Output | 32 bits | Write data driven by the core. |
| `dmem_wstrb_o` | Output | 4 bits | Byte enables (`[0]` for byte 0, `[3]` for byte 3). Little-endian. |
| `dmem_ready_i` | Input | 1 bit | Slave completion acknowledgement. Completes transaction. |
| `dmem_rdata_i` | Input | 32 bits | Read data returned to the core. |
| `dmem_err_i` | Input | 1 bit | Error response flag (e.g. unmapped address or bus fault). |

---

## 4. Instruction Retirement / Commit Signal

| Signal Name | Width | Timing & Behavior |
|-------------|-------|-------------------|
| `instr_retire_o` | 1 bit | Pulses HIGH for exactly **1 clock cycle** whenever an instruction successfully commits/retires at writeback. Pulses for all committed instructions (ALU, Branches, Jumps, Loads, Stores, CSR instructions, Trap entry/MRET). Does not pulse during stall, flush, or idle cycles. |

---

## 5. Performance Event Observation Signals

The core generates 1-cycle active-high pulses for the 8 system events monitored by the Performance Event Counter:

| Event Index | Event Name | Core Signal | Description / Mapping Rule |
|-------------|------------|-------------|----------------------------|
| `0` | Load accepted | `evt_load_o` | Pulses 1 cycle when a data-memory read request is issued (`dmem_req_o & ~dmem_we_o`). |
| `1` | Store accepted | `evt_store_o` | Pulses 1 cycle when a data-memory write request is issued (`dmem_req_o & dmem_we_o`). |
| `2` | Instruction Fetch | `evt_fetch_o` | Pulses 1 cycle when an instruction fetch request is accepted (`imem_req_o`). |
| `3` | Branch / Jump taken | `evt_branch_jump_o` | Pulses 1 cycle when a conditional branch evaluates TRUE, or when JAL / JALR executes. |
| `4` | Pipeline Stall / Bubble | `evt_stall_bubble_o` | Pulses 1 cycle on each memory wait state cycle while waiting for `dmem_ready_i` or `imem_ready_i`. |
| `5` | Exception / Trap taken | `evt_exception_o` | Pulses 1 cycle when an ECALL, EBREAK, illegal instruction, or hardware interrupt trap is taken. |
| `6` | Timer Interrupt Event | `timer_tick` | Pulses 1 cycle when the hardware Timer reaches zero and reloads (`tick_o`). |
| `7` | UART Transmit Complete | `uart_tx_done` | Pulses 1 cycle when the UART transmitter finishes serializing a frame. |
