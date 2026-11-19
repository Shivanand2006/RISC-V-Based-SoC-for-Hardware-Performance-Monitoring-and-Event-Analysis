# Project Proposal

## RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis

---

| Field | Details |
|---|---|
| **Project Title** | RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis |
| **Student ID** | 1602-23-735-108 |
| **Course** | VLSI Design / SoC Design (Final Year Project) |
| **Department** | Electronics & Communication Engineering |
| **Institution** | *[University Name]* |
| **Academic Year** | 2025–2026 |
| **GitHub Repository** | https://github.com/Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis |

---

## 1. Problem Statement

Modern embedded processors execute millions to billions of instructions per second. Understanding *what* the processor is doing at any given moment—how many cycles it spends stalled waiting for memory, how many instructions it retires per cycle, how often it encounters a branch misprediction—is essential to optimising both software and hardware. This discipline is called **Hardware Performance Monitoring (HPM)**.

### 1.1 Limitations of Pure Software Profiling

Traditional software profiling approaches (e.g., `gprof`, `perf` on Linux, cycle-counting loops) suffer from several fundamental limitations:

- **Probe effect**: Instrumented code perturbs the very workload being measured, introducing measurement bias proportional to the overhead of the profiler itself.
- **Coarse granularity**: Software timers typically have a resolution limited by the OS scheduler tick (1–10 ms), far too coarse to characterise micro-architectural behaviour.
- **Missing low-level events**: Branch mispredictions, cache misses, TLB flushes, and stall cycles are CPU micro-architectural events invisible to the software layer unless exposed through dedicated hardware registers.
- **Non-determinism**: Interrupt-driven OS profiling introduces non-determinism that makes reproducible micro-benchmarking difficult.
- **Security boundary**: In a bare-metal or RTOS embedded context, there is no OS profiling infrastructure at all.

### 1.2 Why Dedicated Hardware Counters Are Necessary

The RISC-V ISA specification defines the `mcycle`, `minstret`, and `mhpmcounterN` CSRs precisely to solve these problems. By counting events in hardware:

- Counters advance deterministically with no observer effect.
- 64-bit width prevents overflow on any realistic workload.
- Counter snapshots can be taken in a single atomic CSR read pair.
- Hardware threshold compare with interrupt generation enables low-latency event-driven profiling without polling.

However, the open-source **CHIPS Alliance VeeR EL2** core exposes its performance-related signals as RTL ports rather than fully internally wired CSRs that a designer can extend. This project fills that gap by designing a **memory-mapped HPM subsystem** that wraps those signals into clean, software-accessible registers fully compatible with a standard AHB-Lite SoC bus.

### 1.3 Research Gap

There is currently no open-source, synthesizable, Verilog-2001 HPM IP package designed specifically for the VeeR EL2 that:
- Provides coherent 64-bit counter reads via shadow registers,
- Includes configurable event selection across 8 hardware event sources,
- Integrates a threshold comparator with sticky overflow and maskable interrupt,
- Ships with self-checking unit testbenches and a full SoC-level integration testbench.

This project designs, implements, integrates, and verifies exactly such a system.

---

## 2. Objectives

The following concrete, measurable objectives define the scope of this project:

1. **Design a 64-bit Cycle Counter IP** (`cycle_cnt_top.v`) that:
   - Counts enabled processor clock cycles.
   - Provides shadow-register-based coherent 64-bit reads (read CNT_LO latches CNT_HI).
   - Exposes memory-mapped CTRL, STATUS, CNT_LO, CNT_HI registers.

2. **Design a 64-bit Instruction Retirement Counter IP** (`instr_cnt_top.v`) that:
   - Counts instructions committed by the VeeR EL2 commit stage.
   - Uses the same shadow-register protocol as the cycle counter.
   - Accepts the VeeR `trace_rv_i_valid_ip` retirement signal.

3. **Design a 32-bit Configurable Performance Event Counter IP** (`event_cnt_top.v`) that:
   - Supports 8 selectable hardware events (branches, taken branches, ALU ops, load/store, stall cycles, etc.).
   - Implements a 32-bit threshold comparator with maskable interrupt output.
   - Provides sticky overflow detection and a W1C (Write-1-to-Clear) status register.

4. **Integrate all HPM IPs and peripherals into a complete SoC** (`soc_top.v`) built around the CHIPS Alliance VeeR EL2 (RV32IMC, 4-stage) processor core with:
   - 4 KB IMEM and 4 KB DMEM.
   - UART (16550 subset), Timer (32-bit down-counter), and GPIO (8-bit).
   - A simple bus decoder/interconnect (`bus_decoder.v`) with 1-cycle ready response.

5. **Develop a complete verification environment** including:
   - Self-checking unit testbenches for each HPM IP (`tb_cycle_cnt.v`, `tb_instr_cnt.v`, `tb_event_cnt.v`).
   - An SoC-level testbench (`tb_soc_top.v`) with a passive UART monitor and shadow-counter cross-checks.
   - Simulation using Synopsys VCS with Verdi FSDB waveform capture.

6. **Write bare-metal firmware** in C and RISC-V assembly:
   - Per-IP unit tests: `test_cycle.c`, `test_instr.c`, `test_event.c`.
   - An integrated performance benchmarking application: `perf_app.c`.
   - Startup code: `crt0.S`; register header: `perf_regs.h`.

7. **Demonstrate correctness and utility** of the HPM subsystem by:
   - Proving cycle and instruction counts are accurate to ±1 count.
   - Demonstrating interrupt generation when event count exceeds threshold.
   - Reporting CPI (Cycles Per Instruction) for representative code sequences via `perf_app.c`.

---

## 3. Scope of Work

### 3.1 RTL Design

| Sub-task | Files |
|---|---|
| SoC top-level integration | `soc_top.v` |
| Bus decoder / address demultiplexer | `bus_decoder.v` |
| VeeR EL2 AHB adapter | `veer_core_adapter.sv` |
| Register slave interface (shared) | `reg_slave_if.v` |
| Cycle Counter IP | `cycle_cnt_top.v` |
| Instruction Counter IP | `instr_cnt_top.v` |
| Performance Event Counter IP | `event_cnt_top.v` |
| UART peripheral | `uart_top.v` |
| Timer peripheral | `timer_top.v` |
| GPIO peripheral | `gpio_top.v` |
| Instruction Memory | `imem.v` |
| Data Memory | `dmem.v` |

### 3.2 Firmware / Software

- Startup code and linker scripts (`crt0.S`, `link.ld`)
- Register access header (`perf_regs.h`)
- Per-counter test programs (`test_cycle.c`, `test_instr.c`, `test_event.c`)
- Integrated benchmark application (`perf_app.c`)
- Makefile for RISC-V GNU toolchain compilation
- Hex file generation for simulation memory initialisation

### 3.3 Verification

- Unit testbenches for all three HPM IPs
- Bus decoder testbench (`tb_bus_decoder.v`)
- SoC-level testbench with UART monitor and self-checking assertions
- VCS simulation scripts (`run_ip.sh`)
- Verdi FSDB waveform files for debug

### 3.4 Documentation

- Project Proposal (this document)
- Architecture Specification
- GitHub Setup Guide
- RISC-V Toolchain Setup Guide
- Address Map Specification
- Final Report / README

---

## 4. Tools and Environment

| Tool | Version / Source | Purpose |
|---|---|---|
| **Synopsys VCS** | VCS-MX (university license) | Primary simulation engine |
| **Synopsys Verdi** | Verdi 3 | Waveform debug (FSDB format) |
| **RISC-V GNU Toolchain** | `riscv-gnu-toolchain` (GitHub) `--with-arch=rv32imc` | Cross-compilation for bare-metal firmware |
| **Icarus Verilog (`iverilog`)** | v11+ | Secondary / open-source simulation |
| **GTKWave** | v3.3+ | Open-source VCD waveform viewing |
| **Python 3** | v3.8+ | `bin2hex.py` memory image generation |
| **Git / GitHub** | git 2.x | Version control and collaboration |
| **GNU Make** | v4.x | Build automation |
| **VS Code** | Latest | RTL and firmware editing |

### 4.1 EDA Environment

The VCS + Verdi flow is assumed to be pre-installed in the university server environment. The `run_ip.sh` shell scripts set up the VCS compile and simulation command lines automatically.

### 4.2 RISC-V Toolchain

Built from source for `rv32imc / ilp32` to produce bare-metal ELF binaries. The compiled firmware is converted to Intel HEX format and loaded into the `imem.v` and `dmem.v` models using `$readmemh` at simulation start.

---

## 5. Expected Deliverables

| # | Deliverable | Location |
|---|---|---|
| 1 | Complete synthesizable RTL (Verilog-2001) | `rtl/` |
| 2 | Self-checking unit testbenches | `tb/` |
| 3 | SoC-level testbench with UART monitor | `tb/` |
| 4 | RISC-V bare-metal firmware (C + asm) | `sw/` |
| 5 | Makefile and linker script | `sw/` |
| 6 | VCS simulation run scripts | `run/` |
| 7 | Verdi FSDB waveforms (sample) | `sim_out/` |
| 8 | Project Proposal document | `doc/` |
| 9 | Architecture Specification document | `doc/` |
| 10 | Address Map Specification | `doc/` |
| 11 | GitHub Setup Guide | `doc/` |
| 12 | RISC-V Toolchain Setup Guide | `doc/` |
| 13 | Final Report / README.md | Root |

---

## 6. Project Timeline

| Milestone | Tasks | Target Week |
|---|---|---|
| **M1 – Architecture Freeze** | Finalise memory map, register architecture, HPM IP specs, block diagram | Week 2 |
| **M2 – RTL Design Complete** | All RTL files written and reviewed; bus decoder, reg_slave_if, all 3 HPM IPs, peripherals, SoC top | Week 5 |
| **M3 – Unit Verification** | All unit testbenches passing in VCS; waveforms reviewed in Verdi | Week 7 |
| **M4 – Firmware Complete** | crt0.S, link.ld, perf_regs.h, all test_*.c programs, perf_app.c compiled and generating correct hex | Week 8 |
| **M5 – SoC Integration Verification** | tb_soc_top.v passing; UART monitor producing correct output; shadow counter cross-checks pass | Week 10 |
| **M6 – Documentation and Submission** | All documents written; GitHub repository finalised; final report submitted | Week 12 |

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| VeeR EL2 integration complexity | Medium | High | Use published VeeR EL2 AHB-Lite interface guide; write adapter module early |
| 64-bit shadow read metastability | Low | Medium | Strictly implement latch-on-CNT_LO-read protocol in RTL |
| Toolchain build failures | Medium | Medium | Use pre-built toolchain from SiFive or apt package as fallback |
| VCS license unavailability | Low | High | Maintain iverilog compatibility in all testbenches |
| Firmware linker issues | Medium | Low | Start from known-working crt0.S template for bare-metal RISC-V |

---

*End of Project Proposal*
