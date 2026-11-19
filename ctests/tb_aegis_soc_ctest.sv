`timescale 1ns/1ps
`default_nettype none

// =============================================================================
// File        : tb_soc_ctest.sv
// Description : Standalone boot and execution testbench for compiled VeeR EL2
//               C firmware (soc_c_test.hex / soc_c_test.memh).
// =============================================================================

module tb_soc_ctest;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #10 clk = ~clk; // 50 MHz

    wire uart_tx;
    reg  uart_rx = 1'b1;
    reg  [7:0] gpio_in = 8'h00;
    wire [7:0] gpio_out;

    wire pass_seen;
    wire fail_seen;

    // Instantiate Full SoC Top
    soc_top #(
        .HEX_FILE("soc_c_test.hex")
    ) u_soc_top (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out)
    );

    // Passive UART Monitor
    uart_monitor #(
        .BAUD_RATE   (115200),
        .CLK_FREQ_HZ (50_000_000)
    ) u_uart_mon (
        .clk         (clk),
        .rst_n       (rst_n),
        .uart_tx_pin (uart_tx),
        .pass_seen   (pass_seen),
        .fail_seen   (fail_seen)
    );

    // Clock and Reset Generation
    initial begin
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        $display("[TB_CTEST] Reset released. VeeR EL2 executing from 0x0000_0000...");
    end

`ifdef FSDB
    initial begin
        $fsdbDumpfile("soc_c_test.fsdb");
        $fsdbDumpvars(0, tb_soc_ctest, "+all");
        $fsdbDumpMDA();
        $display("[TB_CTEST] Verdi FSDB waveform dumping enabled: soc_c_test.fsdb");
    end
`endif

    // Completion Handshake and Watchdog
    always @(posedge clk) begin
        if (pass_seen) begin
            $display("\n=================================================");
            $display("[PASS] C-Test completed successfully: SOC_CTEST_RESULT=PASS");
            $display("=================================================");
            #500;
            $finish(0);
        end
        if (fail_seen) begin
            $display("\n[FAIL] C-Test reported FAIL token; aborting.");
            #500;
            $finish(1);
        end
    end

    // Watchdog
    initial begin
        #50_000_000; // 50 ms simulation time
        $display("[FAIL] Watchdog timeout reached without PASS token!");
        $finish(2);
    end

endmodule
`default_nettype wire
