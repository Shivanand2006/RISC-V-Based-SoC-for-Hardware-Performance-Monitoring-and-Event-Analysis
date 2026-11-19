# Test Execution Guide

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  

---

## 1. Quick Start Commands

```bash
# 1. Run full unit regression (All IP testbenches)
./run/run_ip.sh all

# 2. Run SoC Top-level simulation with bare-metal bubble sort
./run/run_ip.sh soc

# 3. Run and launch Verdi GUI
./run/run_verdi.sh soc

# 4. Run bare-metal C test suite
cd ctests && bash build_soc_c_test.sh

# 5. Run UVM Testsuite
cd tb && bash run.sh tb_soc_uvm soc_top_base_test
```

---

## 2. Unit Testbench Execution Flow

Individual IP testbenches can be compiled and run independently without elaborating the CPU core:

```bash
# Cycle Counter unit test
./run/run_ip.sh cycle

# Instruction Counter unit test
./run/run_ip.sh instr

# Performance Event Counter unit test
./run/run_ip.sh event

# Bus Decoder unit test
./run/run_ip.sh decoder
```

---

## 3. Waveform Debugging with Synopsys Verdi

To inspect signals and waveforms:
```bash
# Full SoC top-level waveform
verdi -ssf tb_soc_top.fsdb -dbdir build/sim_soc.daidir &

# Unit test waveforms
verdi -ssf tb_cycle_cnt.fsdb -dbdir build/sim_cycle_cnt.daidir &
verdi -ssf tb_event_cnt.fsdb -dbdir build/sim_event_cnt.daidir &
```

### Pre-configured Signal Groups (`soc_signals.rc`):
Load `soc_signals.rc` inside Verdi to automatically restore:
- Processor Commit Signals (`core_instr_retire`)
- Hardware Event Signals (`core_evt_load`, `core_evt_store`, `core_evt_branch_jump`)
- HPM Counter Registers (`u_cycle_cnt.count_q`, `u_instr_cnt.count_q`, `u_event_cnt.count_q`)
- Peripheral Interfaces (UART, Timer, GPIO)
