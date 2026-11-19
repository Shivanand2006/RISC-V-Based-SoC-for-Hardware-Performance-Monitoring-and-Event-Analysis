# Compilation and Integration Issues Resolved

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  

---

## 1. Issue 1: AHB-Lite to Internal Bus Adapter Synchronization

- **Symptom**: Load/Store Unit (LSU) transactions from the VeeR EL2 core hung when waiting for peripheral acknowledgements on single-cycle unmapped accesses.
- **Root Cause**: The VeeR LSU AHB bus protocol requires an address phase followed by a data phase with pipeline hold when `HREADY` is low. The bus decoder was deasserting `ready` prematurely.
- **Resolution**: Updated `ahb_to_bus_adapter.v` to buffer `haddr` and `hwrite` during the address phase and hold `hready_o` low until `bus_ready_i` asserts from the slave. Unmapped addresses now complete with `ready=1`, `err=1` in exactly 1 clock cycle without processor lockup.

---

## 2. Issue 2: 64-Bit Coherent Shadow Read Race Condition

- **Symptom**: Reading `CNT_LO` followed by `CNT_HI` produced inconsistent snapshots when the low 32 bits wrapped around (`0xFFFF_FFFF` $\rightarrow$ `0x0000_0000`) between the two bus reads.
- **Root Cause**: Counter was incrementing during the intervening read cycle.
- **Resolution**: Added a dedicated `shadow_hi_q` register in both `cycle_cnt_top.v` and `instr_cnt_top.v`. Reading `CNT_LO` (offset `0x08`) atomically captures `count_q[63:32]` into `shadow_hi_q` on the exact same rising clock edge. Reading `CNT_HI` returns this captured value, guaranteeing 100% atomic 64-bit snapshots.

---

## 3. Issue 3: Priority of Synchronous CLEAR over Counting

- **Symptom**: When `CTRL.CLEAR=1` was written simultaneously with incoming retired instruction pulses, the counter value became `1` instead of `0`.
- **Root Cause**: Incrementor logic was evaluated in parallel without strict clear priority.
- **Resolution**: Enforced strict `if (ctrl_clr) count_q <= 0; else if (active) count_q <= count_q + 1;` ordering in sequential clock processes across all three HPM IP blocks.

---

## 4. Issue 4: Write-1-to-Clear (W1C) Race Condition on Status Flags

- **Symptom**: If a new performance event threshold hit occurred on the exact cycle software wrote to clear the `THRESH_HIT` status bit, the event was silently lost.
- **Root Cause**: W1C logic took precedence over live event detection.
- **Resolution**: Updated `event_cnt_top.v` so that new threshold events take precedence over simultaneous W1C clears:
```verilog
if (ctrl_clr) begin
    thresh_hit_q <= 1'b0;
end else if (hit_thresh) begin
    thresh_hit_q <= 1'b1;  // Live event wins over simultaneous clear
end else if (w1c_thrh) begin
    thresh_hit_q <= 1'b0;
end
```
