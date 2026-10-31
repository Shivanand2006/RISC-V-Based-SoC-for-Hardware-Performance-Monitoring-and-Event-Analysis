//=============================================================================
// File: tb_soc_top.v
// Description: Top-level SoC testbench. Provides clock and reset, attaches
//              passive UART monitor, monitors GPIO indicators, tracks shadow
//              performance counters for cross-checking, and enforces watchdog.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps

module tb_soc_top;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // External SoC Pins
    wire       uart_tx;
    reg        uart_rx;
    reg  [7:0] gpio_in;
    wire [7:0] gpio_out;

    // UART Monitor flags
    wire pass_seen;
    wire fail_seen;

    // Testbench Shadow Counters for Independent Cross-Checking
    reg [63:0] tb_cycle_count;
    reg [63:0] tb_instr_count;
    reg [31:0] tb_load_count;
    reg [31:0] tb_store_count;
    reg [31:0] tb_fetch_count;
    reg [31:0] tb_branch_jump_count;
    reg [31:0] tb_stall_count;
    reg [31:0] tb_exception_count;

    // Timeout limit (cycles)
    parameter TIMEOUT_CYCLES = 500_000;
    integer   cycle_idx;

    // Instantiate SoC Top
    soc_top #(
        .HEX_FILE         ("")
    ) u_soc_top (
        .clk              (clk),
        .rst_n            (rst_n),
        .uart_rx          (uart_rx),
        .uart_tx          (uart_tx),
        .gpio_in          (gpio_in),
        .gpio_out         (gpio_out)
    );

    // Instantiate Passive UART Monitor
    uart_monitor #(
        .BAUD_RATE        (115200),
        .CLK_FREQ_HZ      (50_000_000)
    ) u_uart_monitor (
        .clk              (clk),
        .rst_n            (rst_n),
        .uart_tx_pin      (uart_tx),
        .pass_seen        (pass_seen),
        .fail_seen        (fail_seen)
    );

    // Clock Generation (50 MHz -> 20ns period)
    always #10 clk = ~clk;

    // Independent Testbench Shadow Counting (watching internal SoC signals)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb_cycle_count       <= 64'd0;
            tb_instr_count       <= 64'd0;
            tb_load_count        <= 32'd0;
            tb_store_count       <= 32'd0;
            tb_fetch_count       <= 32'd0;
            tb_branch_jump_count <= 32'd0;
            tb_stall_count       <= 32'd0;
            tb_exception_count   <= 32'd0;
        end else begin
            // Increment cycle counter while cycle IP is enabled
            if (u_soc_top.u_cycle_cnt.en_q) begin
                tb_cycle_count <= tb_cycle_count + 64'd1;
            end

            // Increment instruction counter while instruction IP is enabled
            if (u_soc_top.u_instr_cnt.en_q && u_soc_top.core_instr_retire) begin
                tb_instr_count <= tb_instr_count + 64'd1;
            end

            // Track individual events
            if (u_soc_top.core_evt_load)         tb_load_count        <= tb_load_count + 32'd1;
            if (u_soc_top.core_evt_store)        tb_store_count       <= tb_store_count + 32'd1;
            if (u_soc_top.core_evt_fetch)        tb_fetch_count       <= tb_fetch_count + 32'd1;
            if (u_soc_top.core_evt_branch_jump)  tb_branch_jump_count <= tb_branch_jump_count + 32'd1;
            if (u_soc_top.core_evt_stall_bubble) tb_stall_count       <= tb_stall_count + 32'd1;
            if (u_soc_top.core_evt_exception)    tb_exception_count   <= tb_exception_count + 32'd1;
        end
    end

    // GPIO Status Indicator Monitor
    always @(gpio_out) begin
        $display("[TB TIME %0t ps] GPIO_OUT updated: 0x%02h (bit0=%b bit1=%b)",
                 $time, gpio_out, gpio_out[0], gpio_out[1]);
    end

    // Simulation Execution and Watchdog
    initial begin
        clk       = 0;
        rst_n     = 0;
        uart_rx   = 1;
        gpio_in   = 8'h00;
        cycle_idx = 0;

        $display("=================================================");
        $display("Starting RISC-V SoC Top Simulation");
        $display("=================================================");

        // Reset Sequence
        #100;
        @(posedge clk);
        rst_n = 1;
        $display("[TB] Reset released. CPU executing from 0x0000_0000...");

        // Watchdog loop
        for (cycle_idx = 0; cycle_idx < TIMEOUT_CYCLES; cycle_idx = cycle_idx + 1) begin
            @(posedge clk);

            // Termination condition: PASS or FAIL detected via UART or GPIO
            if (pass_seen || gpio_out[0]) begin
                $display("\n=================================================");
                $display("[PASS] SoC Test successfully completed with PASS token!");
                $display("=================================================");
                verify_cross_checks();
                $finish;
            end

            if (fail_seen || gpio_out[1]) begin
                $display("\n=================================================");
                $display("[FAIL] SoC Test completed with FAIL indicator!");
                $display("=================================================");
                verify_cross_checks();
                $finish;
            end
        end

        // Timeout reached
        $display("\n=================================================");
        $display("[FAIL] Global Watchdog Timeout after %0d cycles!", TIMEOUT_CYCLES);
        $display("=================================================");
        verify_cross_checks();
        $finish;
    end

    // End-of-test cross checks task
    task verify_cross_checks;
        begin
            $display("\n--- End-of-Test Architectural Cross-Checks ---");
            $display("  DUT Cycle Counter       : %0d", u_soc_top.u_cycle_cnt.count_q);
            $display("  DUT Instruction Counter : %0d", u_soc_top.u_instr_cnt.count_q);
            $display("  DUT Event Counter       : %0d", u_soc_top.u_event_cnt.count_q);
            $display("  TB Shadow Cycle Counter : %0d", tb_cycle_count);
            $display("  TB Shadow Instr Counter : %0d", tb_instr_count);

            if (u_soc_top.u_cycle_cnt.count_q >= u_soc_top.u_instr_cnt.count_q) begin
                $display("  [PASS] Cross-Check: Cycle count >= Instruction count verified.");
            end else begin
                $display("  [FAIL] Cross-Check: Cycle count (%0d) < Instruction count (%0d)!",
                         u_soc_top.u_cycle_cnt.count_q, u_soc_top.u_instr_cnt.count_q);
            end

            if (u_soc_top.u_cycle_cnt.count_q === tb_cycle_count) begin
                $display("  [PASS] Cross-Check: DUT cycle count matches TB shadow counter.");
            end else begin
                $display("  [FAIL] Cross-Check: DUT cycle count (%0d) != TB shadow (%0d).",
                         u_soc_top.u_cycle_cnt.count_q, tb_cycle_count);
            end

            if (u_soc_top.u_instr_cnt.count_q === tb_instr_count) begin
                $display("  [PASS] Cross-Check: DUT instruction count matches TB shadow counter.");
            end else begin
                $display("  [FAIL] Cross-Check: DUT instr count (%0d) != TB shadow (%0d).",
                         u_soc_top.u_instr_cnt.count_q, tb_instr_count);
            end
        end
    endtask

endmodule
