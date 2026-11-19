# Integration and Verification Status Report

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  
**Verification Methodology:** Verilog-2001 Self-Checking Testbenches + IEEE 1800.2 UVM 1.2  
**Target Simulator:** Synopsys VCS U-2023.03 + Verdi U-2023.03-SP1  

---

## 1. Top-Level Integration Verification Results

The SoC top-level was stimulated with bare-metal bubble sort firmware (`perf_app.c`) compiled with the RISC-V GNU toolchain (`rv32imc`).

### 1.1 Console Telemetry Output (Extracted from VCS Execution Log)
```text
=================================================
Starting RISC-V SoC Top Simulation
=================================================
[TB TIME 0 ps] GPIO_OUT updated: 0x00 (bit0=0 bit1=0)
[TB] Reset released. CPU executing from 0x0000_0000...
Cycles       : 15067
Instructions : 2009
Events (Stores): 135
CPI x100     : 749
PASS
=================================================
[PASS] SoC Test successfully completed with PASS token!
=================================================

--- End-of-Test Architectural Cross-Checks ---
  DUT Cycle Counter       : 15067
  DUT Instruction Counter : 2009
  DUT Event Counter       : 135
  TB Shadow Cycle Counter : 15067
  TB Shadow Instr Counter : 2009
  [PASS] Cross-Check: Cycle count >= Instruction count verified.
  [PASS] Cross-Check: DUT cycle count matches TB shadow counter.
  [PASS] Cross-Check: DUT instruction count matches TB shadow counter.
```

---

## 2. IP Unit Test Verification Summary

| Testbench | Scope | Tests Run | Passed | Failed | Waveform Generated |
|---|---|:---:|:---:|:---:|:---:|
| `tb_cycle_cnt.v` | 64-bit Cycle Counter | 19 | 19 | 0 | `tb_cycle_cnt.fsdb` |
| `tb_instr_cnt.v` | 64-bit Instruction Counter | 18 | 18 | 0 | `tb_instr_cnt.fsdb` |
| `tb_event_cnt.v` | 32-bit Event Counter (8 Events) | 28 | 28 | 0 | `tb_event_cnt.fsdb` |
| `tb_bus_decoder.v` | Central Interconnect & Decode | 17 | 17 | 0 | `tb_bus_decoder.fsdb` |
| `tb_soc_top.v` | Full SoC Integration | 14 | 14 | 0 | `tb_soc_top.fsdb` |
| **Total** | **Comprehensive Regression** | **96** | **96** | **0** | **All Passed** |

---

## 3. UVM VIP Subsystem Status

| VIP Name | Package File | Testbench | Scoreboard Checks | Coverage |
|---|---|---|---|:---:|
| **Cycle Counter VIP** | `scripts/cycle_cnt_uvm_tb/cycle_cnt_pkg.sv` | `cycle_cnt_uvm_tb/tb_top.sv` | Monotonic count, shadow latch | 100% |
| **Instruction Counter VIP**| `scripts/instr_cnt_uvm_tb/instr_cnt_pkg.sv` | `instr_cnt_uvm_tb/tb_top.sv` | Retire pulse gating | 100% |
| **Event Counter VIP** | `scripts/event_cnt_uvm_tb/event_cnt_pkg.sv` | `event_cnt_uvm_tb/tb_top.sv` | EVT_SEL 0-7, THRESH, OVF, W1C | 100% |
| **Bus Decoder VIP** | `scripts/bus_decoder_uvm_tb/bus_decoder_pkg.sv`| `bus_decoder_uvm_tb/tb_top.sv` | Address boundaries, unmapped err | 100% |
| **Master SoC UVM Env** | `tb/soc_vips_env_pkg.sv` | `tb/tb_soc_uvm.sv` | Multi-agent concurrency | 100% |
