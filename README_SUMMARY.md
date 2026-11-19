# RISC-V HPM SoC — Quick Reference Summary

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  
**Repository:** [GitHub: RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis](https://github.com/Shivanand2006/RISC-V-Based-SoC-for-Hardware-Performance-Monitoring-and-Event-Analysis)  
**Status:** ✅ **ALL INTEGRATION & VERIFICATION COMPLETE** — Ready for Final Report & Defense

---

## 📋 Project Overview

| Attribute | Details |
|---|---|
| **Core Architecture** | CHIPS Alliance / Western Digital VeeR EL2 (RV32IMC, 4-stage pipeline) |
| **HPM Blocks** | 64-bit Cycle Counter, 64-bit Instruction Counter, 32-bit 8-Event Performance Counter |
| **Peripherals** | 16550 UART (115200 baud), 32-bit Down-Counter Timer, 8-bit GPIO Controller |
| **Bus Architecture** | Single-cycle request/ready bus with central address decode and error termination |
| **Simulation Metrics** | 15,067 cycles, 2,009 instructions, 135 store events, CPI = 7.49 on bubble sort |
| **Verification Suite** | 96 Verilog self-checking tests + 41 UVM planned tests across 4 dedicated VIPs |
| **Tools Used** | Synopsys VCS U-2023.03, Verdi U-2023.03-SP1, RISC-V GNU Toolchain, Icarus Verilog |

---

## 🚀 Quick Start — 3 Commands

```bash
# 1. Run full unit and SoC regression
./run/run_ip.sh all

# 2. Run SoC demonstration with Verdi waveform dump
./run/run_verdi.sh soc

# 3. Run UVM testsuite
cd tb && bash run.sh tb_soc_uvm soc_top_base_test
```
