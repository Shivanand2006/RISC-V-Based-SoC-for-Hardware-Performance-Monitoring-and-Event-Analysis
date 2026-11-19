# Compilation Status Report — SUCCESSFUL ✅

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  
**Date:** October 31, 2026  
**Executable:** `build/sim_soc` (1.96 MB ELF 64-bit)  
**Compiler:** Synopsys VCS U-2023.03_Full64  
**Status:** ✅ **COMPILATION & SIMULATION SUCCESSFUL (PASS)**

---

## 1. Summary

**Result:** Clean compilation and execution completed with zero fatal errors.

**Evidence of Success:**
```bash
$ ls -lh build/sim_soc
-rwxr-xr-x 1 student student 2.0M Oct 31 15:14 build/sim_soc

$ file build/sim_soc
build/sim_soc: ELF 64-bit LSB executable, x86-64, dynamically linked, for GNU/Linux 3.2.0
```

**Final VCS Compilation & Elaboration Output:**
```
Compiler version U-2023.03_Full64; Runtime version U-2023.03_Full64
*Verdi* Loading libsscore_vcs202303.so
FSDB Dumper for VCS, Release Verdi_U-2023.03-SP1, Linux x86_64/64bit
CPU Time: 32.680 seconds; Data structure size: 1.0Mb
```

---

## 2. IP Unit Test Compilation Matrix

| Subsystem | Simulation Target | Build Log | Status |
|---|---|---|:---:|
| **Cycle Counter (64-bit)** | `build/sim_cycle_cnt` | `build/vcs_compile_cycle_cnt.log` | ✅ PASS |
| **Instruction Counter (64-bit)** | `build/sim_instr_cnt` | `build/vcs_compile_instr_cnt.log` | ✅ PASS |
| **Performance Event Counter (32-bit)** | `build/sim_event_cnt` | `build/vcs_compile_event_cnt.log` | ✅ PASS |
| **Central Bus Interconnect** | `build/sim_decoder` | `build/vcs_compile_decoder.log` | ✅ PASS |
| **Full SoC Top-Level (VeeR EL2)** | `build/sim_soc` | `build/vcs_compile_soc.log` | ✅ PASS |

---

## 3. Waveform Generation Status
- `tb_soc_top.fsdb`: Generated successfully (KDB + Verdi FSDB full hierarchy dumped).
- `tb_cycle_cnt.fsdb`: Generated.
- `tb_instr_cnt.fsdb`: Generated.
- `tb_event_cnt.fsdb`: Generated.
- `tb_bus_decoder.fsdb`: Generated.
