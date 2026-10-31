//=============================================================================
// File: tb_instr_cnt.v
// Description: Self-checking unit testbench for the 64-bit Instruction Counter IP.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps
`include "instr_cnt_defines.vh"

module tb_instr_cnt;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Retirement signal
    reg instr_retire;

    // Bus signals
    reg         bus_req;
    reg         bus_we;
    reg  [7:0]  bus_addr;
    reg  [31:0] bus_wdata;
    reg  [3:0]  bus_wstrb;
    wire        bus_ready;
    wire [31:0] bus_rdata;
    wire        bus_err;

    // Test tracking
    integer fail_count = 0;
    integer pass_count = 0;

    // Instantiate DUT
    instr_cnt_top #(
        .ADDR_WIDTH  (8),
        .DATA_WIDTH  (32),
        .STRB_WIDTH  (4),
        .RETIRE_WIDTH(1)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .instr_retire_i(instr_retire),
        .bus_req_i     (bus_req),
        .bus_we_i      (bus_we),
        .bus_addr_i    (bus_addr),
        .bus_wdata_i   (bus_wdata),
        .bus_wstrb_i   (bus_wstrb),
        .bus_ready_o   (bus_ready),
        .bus_rdata_o   (bus_rdata),
        .bus_err_o     (bus_err)
    );

    // Clock generation (50MHz -> 20ns period)
    always #10 clk = ~clk;

    // BFM Tasks
    task bus_write;
        input [7:0]  addr;
        input [31:0] data;
        input [3:0]  strb;
        output       err;
        begin
            @(posedge clk);
            bus_req   <= 1'b1;
            bus_we    <= 1'b1;
            bus_addr  <= addr;
            bus_wdata <= data;
            bus_wstrb <= strb;
            @(posedge clk);
            while (!bus_ready) @(posedge clk);
            err = bus_err;
            bus_req <= 1'b0;
            bus_we  <= 1'b0;
        end
    endtask

    task bus_read;
        input  [7:0]  addr;
        output [31:0] data;
        output        err;
        begin
            @(posedge clk);
            bus_req   <= 1'b1;
            bus_we    <= 1'b0;
            bus_addr  <= addr;
            bus_wstrb <= 4'b0000;
            @(posedge clk);
            while (!bus_ready) @(posedge clk);
            data = bus_rdata;
            err  = bus_err;
            bus_req <= 1'b0;
        end
    endtask

    task check_val;
        input [31:0] actual;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s: expected 0x%08h, got 0x%08h", test_name, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: expected 0x%08h, got 0x%08h", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_flag;
        input actual;
        input expected;
        input [255:0] test_name;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s: expected %b, got %b", test_name, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: expected %b, got %b", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [31:0] rdata;
    reg [31:0] rdata_lo;
    reg [31:0] rdata_hi;
    reg        err;

    initial begin
        clk          = 0;
        rst_n        = 0;
        instr_retire = 0;
        bus_req      = 0;
        bus_we       = 0;
        bus_addr     = 0;
        bus_wdata    = 0;
        bus_wstrb    = 0;

        $display("=================================================");
        $display("Starting Instruction Counter Unit Testbench");
        $display("=================================================");

        // Step 1: Reset sequence
        #45;
        rst_n = 1;
        #20;

        // Test 1: Reset defaults
        $display("\n--- Test 1: Check Reset Defaults ---");
        bus_read(`INSTR_CNT_REG_CTRL, rdata, err);
        check_val(rdata, 32'h0, "Reset CTRL register");
        check_flag(err, 1'b0, "Reset CTRL no error");

        bus_read(`INSTR_CNT_REG_STATUS, rdata, err);
        check_val(rdata, 32'h0, "Reset STATUS register");

        bus_read(`INSTR_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'h0, "Reset CNT_LO register");

        bus_read(`INSTR_CNT_REG_CNT_HI, rdata, err);
        check_val(rdata, 32'h0, "Reset CNT_HI register");

        // Test 2: Inactive hold (count does not advance while EN=0 even with retire pulses)
        $display("\n--- Test 2: Inactive Hold (EN=0 with retire pulses) ---");
        repeat (5) begin
            @(posedge clk);
            instr_retire <= 1'b1;
            @(posedge clk);
            instr_retire <= 1'b0;
        end
        bus_read(`INSTR_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'h0, "CNT_LO remains 0 while disabled");

        // Test 3: Enable counter and ignore cycles without instr_retire_i
        $display("\n--- Test 3: Enable Counter, verify cycles without retire ignored ---");
        bus_write(`INSTR_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN = 1
        check_flag(err, 1'b0, "Enable write OKAY");

        // Let clock run for 20 cycles with instr_retire = 0
        repeat (20) @(posedge clk);
        bus_read(`INSTR_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'h0, "No increment without instr_retire_i");

        // Test 4: Pulse instr_retire exactly 10 times and verify count
        $display("\n--- Test 4: Count Exactly 10 Retired Instructions ---");
        repeat (10) begin
            @(posedge clk);
            instr_retire <= 1'b1;
            @(posedge clk);
            instr_retire <= 1'b0;
            repeat (2) @(posedge clk); // Gap between retirements
        end
        bus_read(`INSTR_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'd10, "CNT_LO equals exactly 10");

        // Test 5: CLEAR priority over counting
        $display("\n--- Test 5: CLEAR Priority Over Counting ---");
        @(posedge clk);
        instr_retire <= 1'b1;
        bus_write(`INSTR_CNT_REG_CTRL, 32'h3, 4'hF, err); // EN=1, CLEAR=1
        instr_retire <= 1'b0;
        bus_read(`INSTR_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'd0, "CLEAR has priority over counting");

        // Test 6: Coherent 64-bit Read
        $display("\n--- Test 6: Coherent 64-bit Read Sequence ---");
        dut.preload_count(64'h0000_0008_FFFF_FFF5);
        bus_write(`INSTR_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN = 1

        // Read CNT_LO: captures shadow_hi
        bus_read(`INSTR_CNT_REG_CNT_LO, rdata_lo, err);

        // Retire 20 instructions to advance count past carry into next value
        repeat (20) begin
            @(posedge clk);
            instr_retire <= 1'b1;
            @(posedge clk);
            instr_retire <= 1'b0;
        end

        // Read CNT_HI: should return 0x8 from shadow register
        bus_read(`INSTR_CNT_REG_CNT_HI, rdata_hi, err);
        check_val(rdata_hi, 32'h0000_0008, "Coherent CNT_HI shadow read");

        // Test 7: Carry into CNT_HI
        $display("\n--- Test 7: Carry Propagation into CNT_HI ---");
        dut.preload_count(64'h0000_0000_FFFF_FFFF);
        @(posedge clk);
        instr_retire <= 1'b1;
        @(posedge clk);
        instr_retire <= 1'b0;
        repeat (2) @(posedge clk);

        bus_read(`INSTR_CNT_REG_CNT_LO, rdata_lo, err);
        bus_read(`INSTR_CNT_REG_CNT_HI, rdata_hi, err);
        check_val(rdata_lo, 32'h0000_0000, "CNT_LO wrapped to 0");
        check_val(rdata_hi, 32'h0000_0001, "CNT_HI incremented to 1");

        // Test 8: Write to Read-Only Registers Ignored
        $display("\n--- Test 8: Write to Read-Only Registers Ignored ---");
        bus_write(`INSTR_CNT_REG_STATUS, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to STATUS accepted without error");

        bus_write(`INSTR_CNT_REG_CNT_LO, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to CNT_LO accepted without error");

        bus_write(`INSTR_CNT_REG_CNT_HI, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to CNT_HI accepted without error");

        // Test 9: Undefined offset returns error response
        $display("\n--- Test 9: Undefined Offset Error Response ---");
        bus_read(8'h10, rdata, err);
        check_flag(err, 1'b1, "Read undefined offset 0x10 returns error");

        bus_write(8'h18, 32'hA5A5_A5A5, 4'hF, err);
        check_flag(err, 1'b1, "Write undefined offset 0x18 returns error");

        // Summary
        $display("\n=================================================");
        $display("Instruction Counter Unit Test Summary:");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=================================================");

        if (fail_count == 0) begin
            $display("[PASS] Instruction Counter Unit Tests PASSED completely.\n");
        end else begin
            $display("[FAIL] Instruction Counter Unit Tests FAILED with %0d errors.\n", fail_count);
        end

        $finish;
    end

endmodule
