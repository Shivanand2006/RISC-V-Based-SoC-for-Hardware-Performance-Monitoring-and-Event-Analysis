# Simulation Timeout and Watchdog Guide

**Project:** RISC-V Based SoC for Hardware Performance Monitoring and Event Analysis  
**Student ID:** 1602-23-735-108  

---

## 1. Watchdog Architecture in `tb_soc_top.v`

To prevent deadlocks or infinite loops from consuming compute resources during regression, `tb_soc_top.v` incorporates a hardware watchdog timer:

```verilog
parameter TIMEOUT_CYCLES = 2_000_000; // 2,000,000 cycles at 50 MHz = 40 ms simulation time
integer cycle_idx;

initial begin
    for (cycle_idx = 0; cycle_idx < TIMEOUT_CYCLES; cycle_idx = cycle_idx + 1) begin
        @(posedge clk);
    end
    $display("[FAIL] Simulation Watchdog Timeout Reached (%0d cycles)!", TIMEOUT_CYCLES);
    $finish(2);
end
```

---

## 2. UART Baud Simulation Optimization

At 50 MHz with a 115,200 baud rate, transmitting a single 10-bit serial UART frame takes:
$$\frac{50,000,000}{115,200} \times 10 = 4,340 \text{ clock cycles} = 86.8\,\mu\text{s}$$

Transmitting a 50-character banner requires ~217,000 clock cycles. 

### Recommendations for Rapid Simulation:
1. **Batch Regressions**: Set `DIVISOR = 4` in `sw/perf_regs.h` during simulation regression to accelerate UART transmission by $100\times$.
2. **FSDB Auto-Flush**: Always pass `+fsdb+autoflush` to VCS to preserve waveform buffers even if a timeout triggers.
3. **Passive Monitor Watching**: The testbench passive UART monitor watches `uart_tx_pin` continuously and terminates simulation immediately upon seeing the `PASS\n` token, avoiding unnecessary post-execution cycles.
