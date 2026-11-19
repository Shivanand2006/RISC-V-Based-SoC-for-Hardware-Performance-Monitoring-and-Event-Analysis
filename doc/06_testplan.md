# Test Plan: RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis

**Project Title:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  
**Version:** 1.0  
**Date:** November 2026  
**Prepared By:** Student 1602-23-735-108  
**Reviewed By:** Project Supervisor  

---

## 1. Introduction

This document defines the verification test plan for the RISC-V-based SoC containing Hardware Performance Monitor (HPM) IP blocks: Cycle Counter, Instruction Counter, and Event Counter. The plan covers both black-box (External) tests driven at module I/O ports and white-box (Internal) tests using hierarchical references and backdoor access, targeting 100% functional and statement coverage.

---

## 2. Test Plan Summary

| Block | Total Tests | P1 | P2 | P3 | External | Internal |
|---|---|---|---|---|---|---|
| Boot & System | 4 | 3 | 1 | 0 | 3 | 1 |
| Bus Decoder | 5 | 3 | 2 | 0 | 3 | 2 |
| Cycle Counter | 8 | 4 | 3 | 1 | 5 | 3 |
| Instruction Counter | 6 | 3 | 2 | 1 | 4 | 2 |
| Event Counter | 12 | 5 | 5 | 2 | 7 | 5 |
| SoC Integration | 4 | 2 | 1 | 1 | 3 | 1 |
| Regression | 2 | 1 | 1 | 0 | 2 | 0 |
| **TOTAL** | **41** | **21** | **15** | **5** | **27** | **14** |

---

## 3. Master Test Plan Table

| S.No | Test Name | Block | Priority | Description | Test Type | Stimulus | Expected Result | Pass Criteria | C Test File | SV/UVM Test |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | TC_BOOT_RESET | Boot & System | P1 | Verify power-on reset initialises all registers to 0 | External | Assert rst_n=0 for 10 cycles, deassert | All counter registers read 0; STATUS=0 | No ERR; all reads return 32'h0 | — | hpm_test_base::reset_dut() |
| 2 | TC_BOOT_CLKGEN | Boot & System | P1 | Verify clock generation and stable operation at 50 MHz | External | Observe clk toggling post-reset | clk toggles at 20 ns period | Period measured = 20 ns ±50 ps | — | hpm_tb_top clock check |
| 3 | TC_BOOT_UART_PASS | Boot & System | P1 | Verify test_cycle.c transmits "PASS" token over UART | External | Load test_cycle.elf; run to completion | UART TX sends ASCII "PASS\n" | uart_tx captures PASS sequence | test_cycle.c | hpm_test_cycle |
| 4 | TC_BOOT_BACKDR | Boot & System | P2 | Backdoor force EN=1; verify STATUS reflects RUNNING=1 without bus write | Internal | Hierarchical force: `tb.dut.cycle_cnt.en_r = 1` | STATUS[0] reads 1 | STATUS bit 0 = 1 at next posedge | — | hpm_test_base internal |
| 5 | TC_BUS_IMEM | Bus Decoder | P1 | Write and read-back from IMEM region (0x0000_0000) | External | bus_addr=0x0000_0000, bus_we=1 | bus_ready=1, bus_err=0 | rdata matches wdata after read | — | bus_decoder_seq::each_mapped_region |
| 6 | TC_BUS_DMEM | Bus Decoder | P1 | Write and read-back from DMEM region (0x0000_1000) | External | bus_addr=0x0000_1000, bus_we=1 | bus_ready=1, bus_err=0 | rdata matches wdata | — | bus_decoder_seq::each_mapped_region |
| 7 | TC_BUS_PERIPH | Bus Decoder | P1 | Access UART/Timer/GPIO regions; verify correct decode | External | bus_addr ∈ {0x2000,0x2100,0x2200} | bus_ready=1, bus_err=0 | No error asserted | — | bus_decoder_seq::each_mapped_region |
| 8 | TC_BUS_UNMAP | Bus Decoder | P2 | Access unmapped address (0x0000_3000) | External | bus_addr=0x0000_3000, bus_req=1 | bus_err=1 | bus_err asserted within 1 cycle | — | bus_decoder_seq::unmapped_error |
| 9 | TC_BUS_BACKBACK | Bus Decoder | P2 | Drive back-to-back transactions with no idle | Internal | Drive req=1 consecutively for 10 beats | All beats complete with ready=1, err=0 | Zero lost transactions | — | bus_decoder_seq::back_to_back |
| 10 | TC_CYC_ENABLE | Cycle Counter | P1 | Write CTRL[0]=1 (EN) and verify counter increments | External | Write 0x2300+0x00 = 0x01; read CNT_LO after N clocks | CNT_LO = N (±pipeline latency) | CNT_LO > 0 after 10 clocks | test_cycle.c | hpm_test_cycle |
| 11 | TC_CYC_DISABLE | Cycle Counter | P1 | Clear EN bit and verify counter freezes | External | Write CTRL=0x01; wait 50 clk; write CTRL=0x00; wait 20 clk; read CNT_LO twice | Both reads return same value | CNT_LO(read1) == CNT_LO(read2) | test_cycle.c | hpm_test_cycle |
| 12 | TC_CYC_CLEAR | Cycle Counter | P1 | Write CTRL[1]=1 (CLEAR) and verify counter resets | External | Write CTRL=0x03 (EN+CLEAR); read CNT_LO | CNT_LO = 0 or 1 | CNT_LO ≤ 1 | test_cycle.c | hpm_test_cycle |
| 13 | TC_CYC_STATUS | Cycle Counter | P2 | Verify STATUS[0] = RUNNING mirrors EN | External | Write CTRL=0x01; read STATUS; write CTRL=0x00; read STATUS | STATUS=0x1 when EN, 0x0 when not | STATUS[0]==EN[0] at all checks | test_cycle.c | hpm_test_cycle |
| 14 | TC_CYC_SHADOW | Cycle Counter | P2 | Read CNT_LO latches CNT_HI into shadow register | External | Enable; wait; read CNT_LO; then read CNT_HI | CNT_HI is snapshot at time of CNT_LO read | No glitch between LO/HI pair | test_cycle.c | hpm_test_cycle shadow_read_seq |
| 15 | TC_CYC_SHADOW_INT | Cycle Counter | P2 | Verify internal shadow latch toggles on CNT_LO read | Internal | Hierarchical: observe `cnt_hi_shadow` after CNT_LO read | Shadow register value == CNT_HI at sample point | shadow_r == cnt_hi_r before bus read | — | hpm_test_cycle internal |
| 16 | TC_CYC_64WRAP | Cycle Counter | P3 | Force CNT near 64-bit max and verify wrap to 0 | Internal | Backdoor write cnt_r = 64'hFFFF_FFFF_FFFF_FFFE; enable; wait 3 clk | CNT_LO/HI wraps from max to 0x1 | cnt_r rolls over without stall | — | cycle_cnt_seq::wrap_test_seq |
| 17 | TC_CYC_HOLD | Cycle Counter | P1 | Verify counter does not increment when EN=0 | External | Reset; leave CTRL=0x00; wait 100 clk; read CNT_LO | CNT_LO = 0 | CNT_LO == 32'h0 | — | hpm_test_cycle |
| 18 | TC_INSTR_ENABLE | Instruction Counter | P1 | Verify counter increments only when EN=1 AND instr_retire=1 | External | Write CTRL=0x01; pulse instr_retire for 10 cycles | CNT_LO = 10 | CNT_LO == 10 exactly | test_instr.c | hpm_test_instr |
| 19 | TC_INSTR_NORETIRE | Instruction Counter | P1 | Verify counter does NOT increment on clock alone (no retire) | External | Write CTRL=0x01; hold instr_retire=0 for 50 clk; read CNT_LO | CNT_LO = 0 | CNT_LO == 32'h0 | test_instr.c | hpm_test_instr |
| 20 | TC_INSTR_CLEAR | Instruction Counter | P1 | Clear and verify reset | External | Write CTRL=0x03; read CNT_LO | CNT_LO == 0 | CNT_LO ≤ 1 | test_instr.c | hpm_test_instr |
| 21 | TC_INSTR_SHADOW | Instruction Counter | P2 | Shadow register atomic capture | External | Enable; retire 20 instr; read CNT_LO; read CNT_HI | HI consistent with LO read timestamp | No intermediate increment between LO/HI reads | test_instr.c | instr_cnt_seq::shadow_read_seq |
| 22 | TC_INSTR_CONCUR | Instruction Counter | P2 | Concurrent enable with Cycle Counter; verify independent counts | External | Enable both; wait 50 clk; retire only 30 instr | Cycle CNT_LO ≈50; Instr CNT_LO = 30 | Each counter independent | test_instr.c | hpm_test_instr concurrent_cycle_instr |
| 23 | TC_INSTR_SHADOW_INT | Instruction Counter | P3 | Backdoor verify shadow latch in instruction counter | Internal | Force cnt_r value; read CNT_LO; check shadow_r | shadow_r == cnt_hi_r at read | Internal register matches | — | hpm_test_instr internal |
| 24 | TC_EVT_SEL0_LOAD | Event Counter | P1 | EVT_SEL=0 (Load); drive 10 load pulses; verify COUNT=10 | External | Write EVT_SEL=0; EN; drive events_in[0]=1 ×10; read COUNT | COUNT == 10 | COUNT == 32'd10 | test_event.c | hpm_test_event evt_sel0_seq |
| 25 | TC_EVT_SEL1_STORE | Event Counter | P1 | EVT_SEL=1 (Store); drive 8 store pulses; verify COUNT=8 | External | Write EVT_SEL=1; EN; drive events_in[1]=1 ×8; read COUNT | COUNT == 8 | COUNT == 32'd8 | test_event.c | hpm_test_event |
| 26 | TC_EVT_SEL2_FETCH | Event Counter | P2 | EVT_SEL=2 (Fetch); drive 15 fetch pulses | External | Write EVT_SEL=2; drive events_in[2] ×15 | COUNT == 15 | COUNT == 32'd15 | test_event.c | hpm_test_event evt_sel2_seq |
| 27 | TC_EVT_SEL3_BRANCH | Event Counter | P2 | EVT_SEL=3 (Branch/Jump) | External | Write EVT_SEL=3; drive events_in[3] ×7 | COUNT == 7 | COUNT == 32'd7 | test_event.c | hpm_test_event evt_sel3_seq |
| 28 | TC_EVT_SEL4_STALL | Event Counter | P2 | EVT_SEL=4 (Stall) | External | Write EVT_SEL=4; drive events_in[4] ×20 | COUNT == 20 | COUNT == 32'd20 | — | hpm_test_event evt_sel4_seq |
| 29 | TC_EVT_SEL5_EXCEP | Event Counter | P2 | EVT_SEL=5 (Exception) | External | Write EVT_SEL=5; drive events_in[5] ×3 | COUNT == 3 | COUNT == 32'd3 | — | hpm_test_event evt_sel5_seq |
| 30 | TC_EVT_SEL6_TIMER | Event Counter | P2 | EVT_SEL=6 (Timer Tick) | External | Write EVT_SEL=6; drive events_in[6] ×50 | COUNT == 50 | COUNT == 32'd50 | — | hpm_test_event evt_sel6_seq |
| 31 | TC_EVT_SEL7_UART | Event Counter | P2 | EVT_SEL=7 (UART TX Done) | External | Write EVT_SEL=7; drive events_in[7] ×5 | COUNT == 5 | COUNT == 32'd5 | — | hpm_test_event evt_sel7_seq |
| 32 | TC_EVT_THRESH | Event Counter | P1 | Write THRESH=5; drive 6 events; verify THRESH_HIT=1 | External | Write THRESH=5; EN; drive 6 pulses on selected event | STATUS[1]=1 (THRESH_HIT) | STATUS[1] == 1 | test_event.c | hpm_test_event thresh_test_seq |
| 33 | TC_EVT_OVF | Event Counter | P1 | Force COUNT near 32'hFFFF_FFFF; verify OVF on next pulse | Internal | Backdoor: cnt_r = 32'hFFFF_FFFE; drive 3 pulses | STATUS[0]=1 (OVF) | STATUS[0] == 1 | — | hpm_test_event overflow_test_seq |
| 34 | TC_EVT_W1C | Event Counter | P1 | Write STATUS[1]=1 (W1C); verify THRESH_HIT cleared | External | Trigger THRESH_HIT; write STATUS=0x02; read STATUS | STATUS[1] = 0 | STATUS[1] == 1'b0 after write | test_event.c | hpm_test_event w1c_seq |
| 35 | TC_EVT_IRQ_EN | Event Counter | P2 | Verify IRQ fires when CTRL[2]=IRQ_EN=1 and OVF/THRESH occurs | External | Write CTRL[2]=1; trigger overflow | irq_o asserts | irq_o==1 within 2 cycles of OVF | test_event.c | hpm_test_event irq_test_seq |
| 36 | TC_EVT_IRQ_DIS | Event Counter | P2 | Verify IRQ suppressed when IRQ_EN=0 | External | Write CTRL[2]=0; trigger overflow | irq_o stays 0 | irq_o==0 throughout | — | hpm_test_event irq_test_seq |
| 37 | TC_EVT_W1C_OVF_INT | Event Counter | P3 | Backdoor: verify OVF flag internal register clears on W1C | Internal | Trigger OVF; write STATUS=0x01; probe internal ovf_r | ovf_r == 0 | Internal ovf_r == 1'b0 | — | hpm_test_event internal |
| 38 | TC_SOC_CONCURRENT | SoC Integration | P1 | Run all 3 counters concurrently; verify independence | External | Enable Cycle, Instr (retire=1 always), Event (evt_sel=0, load=1 always); run 100 clk | Each COUNT reflects correct individual count | Cycle≈100, Instr≈100, Event≈100 | perf_app.c | hpm_test_soc |
| 39 | TC_SOC_PERF_APP | SoC Integration | P1 | Run perf_app.c bubble sort; verify UART output "PASS" | External | Load perf_app.elf; run to completion | UART prints performance metrics + PASS | PASS token received | perf_app.c | hpm_test_soc |
| 40 | TC_SOC_RESET_MID | SoC Integration | P2 | Assert reset mid-test; verify all counters reset cleanly | External | Enable all counters; wait 50 clk; assert rst_n=0; deassert | All registers read 0 post-reset | No residual counts | — | hpm_test_base::reset_dut() mid-run |
| 41 | TC_REGRESS_ALL | Regression | P1 | Run run_ip.sh against all 5 testbenches | External | Execute: `./run_ip.sh all` | All 5 TBs report PASS | 0 failures in regression log | all | All UVM tests via run_ip.sh |

---

## 4. Coverage Plan

### 4.1 Cycle Counter Functional Coverage

| Coverage Group | Coverage Points |
|---|---|
| `cg_addr` | CTRL(0x00), STATUS(0x04), CNT_LO(0x08), CNT_HI(0x0C) |
| `cg_access` | Write(we=1), Read(we=0) |
| `cg_cross_addr_access` | Cross: all 4 addresses × {Read, Write} |
| `cg_ctrl_en` | EN=0, EN=1 |
| `cg_ctrl_clear` | CLEAR=0, CLEAR=1 |
| `cg_shadow_trigger` | CNT_LO read while running, CNT_LO read while stopped |
| `cg_wrap` | Counter overflow (bit 32 carry), no overflow |

**Target: 100% functional coverage**

---

### 4.2 Instruction Counter Functional Coverage

| Coverage Group | Coverage Points |
|---|---|
| `cg_retire` | instr_retire=0 with EN=1, instr_retire=1 with EN=1, instr_retire=1 with EN=0 |
| `cg_addr` | CTRL, STATUS, CNT_LO, CNT_HI |
| `cg_cross_retire_en` | Cross: retire × EN |
| `cg_shadow_trigger` | CNT_LO read (shadow latch event) |
| `cg_concurrent` | Cycle counter also enabled simultaneously |

---

### 4.3 Event Counter Functional Coverage

| Coverage Group | Coverage Points |
|---|---|
| `cg_evt_sel` | All 8 values: 0–7 |
| `cg_addr` | CTRL(0x00), EVT_SEL(0x04), COUNT(0x08), THRESH(0x0C), STATUS(0x10) |
| `cg_ctrl_bits` | EN, CLEAR, IRQ_EN each = {0,1} |
| `cg_status_ovf` | OVF=0, OVF=1 |
| `cg_status_thresh` | THRESH_HIT=0, THRESH_HIT=1 |
| `cg_w1c_ovf` | W1C write to OVF bit |
| `cg_w1c_thresh` | W1C write to THRESH_HIT bit |
| `cg_irq_gating` | IRQ_EN=1 with OVF, IRQ_EN=0 with OVF |
| `cg_cross_sel_access` | Cross: evt_sel[2:0] × {read COUNT, drive event pulse} |

---

### 4.4 Bus Decoder Functional Coverage

| Coverage Group | Coverage Points |
|---|---|
| `cg_target_region` | IMEM, DMEM, UART, Timer, GPIO, Cycle_Cnt, Instr_Cnt, Event_Cnt, UNMAPPED |
| `cg_access_type` | Read, Write |
| `cg_error_response` | err=0 (valid), err=1 (unmapped) |
| `cg_wstrb` | 4'b0001, 4'b0011, 4'b1111 (byte, halfword, word) |
| `cg_cross_region_access` | Cross: all 9 target regions × {Read, Write} |

---

### 4.5 SoC Integration Coverage

| Coverage Group | Coverage Points |
|---|---|
| `cg_counters_concurrent` | Only Cycle, Only Instr, Only Event, All three simultaneously |
| `cg_irq_concurrent` | IRQ during counter read, IRQ during counter clear |
| `cg_perf_app` | perf_app completes with PASS, perf_app encounters FAIL |

---

## 5. Regression Strategy

| Run | Command | Tests | Target |
|---|---|---|---|
| Nightly | `./run_ip.sh all` | All 41 | 0 failures |
| Cycle Only | `./run_ip.sh cycle` | TC_CYC_* | 100% pass |
| Event Only | `./run_ip.sh event` | TC_EVT_* | 100% pass |
| Integration | `./run_ip.sh soc` | TC_SOC_* | 100% pass |
| Coverage | `./run_ip.sh cov` | All + URG | >95% functional coverage |

---

## 6. Tools and Environment

| Item | Detail |
|---|---|
| Simulator | Synopsys VCS / Questa / Cadence Xcelium |
| UVM Version | IEEE 1800.2-2017 (UVM 1.2) |
| Waveform | Synopsys Verdi (.fsdb format) |
| Coverage | URG (VCS) / Questa Coverage |
| OS | Linux (or Windows WSL2) |
| HDL | SystemVerilog (IEEE 1800-2017) |
| C Compiler | RISC-V GCC (riscv32-unknown-elf-gcc) |
