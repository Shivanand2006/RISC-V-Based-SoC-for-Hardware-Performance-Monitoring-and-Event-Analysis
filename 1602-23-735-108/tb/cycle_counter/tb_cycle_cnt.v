//=============================================================================
// File: tb_cycle_cnt.v
// Description: Self-checking unit testbench for the 64-bit Cycle Counter IP.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps
`include "cycle_cnt_defines.vh"

module tb_cycle_cnt;

    // Clock and Reset
    reg clk;
    reg rst_n;

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

    // Instantiate DUT with SIM macro enabled
    cycle_cnt_top #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32),
        .STRB_WIDTH(4)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .bus_req_i  (bus_req),
        .bus_we_i   (bus_we),
        .bus_addr_i (bus_addr),
        .bus_wdata_i(bus_wdata),
        .bus_wstrb_i(bus_wstrb),
        .bus_ready_o(bus_ready),
        .bus_rdata_o(bus_rdata),
        .bus_err_o  (bus_err)
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
        clk       = 0;
        rst_n     = 0;
        bus_req   = 0;
        bus_we    = 0;
        bus_addr  = 0;
        bus_wdata = 0;
        bus_wstrb = 0;

        $display("=================================================");
        $display("Starting Cycle Counter Unit Testbench");
        $display("=================================================");

        // Step 1: Reset sequence
        #45;
        rst_n = 1;
        #20;

        // Test 1: Reset defaults
        $display("\n--- Test 1: Check Reset Defaults ---");
        bus_read(`CYCLE_CNT_REG_CTRL, rdata, err);
        check_val(rdata, 32'h0, "Reset CTRL register");
        check_flag(err, 1'b0, "Reset CTRL no error");

        bus_read(`CYCLE_CNT_REG_STATUS, rdata, err);
        check_val(rdata, 32'h0, "Reset STATUS register");

        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'h0, "Reset CNT_LO register");

        bus_read(`CYCLE_CNT_REG_CNT_HI, rdata, err);
        check_val(rdata, 32'h0, "Reset CNT_HI register");

        // Test 2: Inactive hold (count does not advance while EN=0)
        $display("\n--- Test 2: Inactive Hold (EN=0) ---");
        repeat (10) @(posedge clk);
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, 32'h0, "CNT_LO remains 0 while disabled");

        // Test 3: Enable counter and observe counting
        $display("\n--- Test 3: Enable Counter ---");
        bus_write(`CYCLE_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN = 1
        check_flag(err, 1'b0, "Enable write OKAY");

        bus_read(`CYCLE_CNT_REG_STATUS, rdata, err);
        check_val(rdata, 32'h1, "STATUS reflects RUNNING=1");

        repeat (20) @(posedge clk);
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata, err);
        if (rdata > 32'd15) begin
            $display("  [PASS] Counter incrementing: count = %0d", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Counter not incrementing properly: count = %0d", rdata);
            fail_count = fail_count + 1;
        end

        // Test 4: Disable counter and verify hold
        $display("\n--- Test 4: Disable Counter and Verify Hold ---");
        bus_write(`CYCLE_CNT_REG_CTRL, 32'h0, 4'hF, err); // EN = 0
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata_lo, err);
        repeat (10) @(posedge clk);
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata, err);
        check_val(rdata, rdata_lo, "Counter holds value when disabled");

        // Test 5: CLEAR priority over counting
        $display("\n--- Test 5: CLEAR Priority Over Counting ---");
        // Write both EN=1 and CLEAR=1 simultaneously
        bus_write(`CYCLE_CNT_REG_CTRL, 32'h3, 4'hF, err);
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata, err);
        // Should have reset to 0 (or small count right after clear)
        check_val(rdata < 32'd5 ? 32'd0 : rdata, 32'd0, "CLEAR has priority over counting");

        // Test 6: Coherent 64-bit Read
        $display("\n--- Test 6: Coherent 64-bit Read Sequence ---");
        // Preload counter close to wrap so count has high bits: 0x0000_0005_FFFF_FFF0
        dut.preload_count(64'h0000_0005_FFFF_FFF0);
        bus_write(`CYCLE_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN = 1
        repeat (5) @(posedge clk);

        // Read CNT_LO: captures shadow_hi
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata_lo, err);
        // Wait several cycles during which count wraps into higher value
        repeat (30) @(posedge clk);
        // Read CNT_HI: should return the captured shadow value 0x5, not whatever count[63:32] is now
        bus_read(`CYCLE_CNT_REG_CNT_HI, rdata_hi, err);
        check_val(rdata_hi, 32'h0000_0005, "Coherent CNT_HI shadow read");

        // Test 7: Counter Carry into CNT_HI
        $display("\n--- Test 7: 64-bit Carry into CNT_HI ---");
        dut.preload_count(64'h0000_0000_FFFF_FFFE);
        repeat (5) @(posedge clk);
        bus_read(`CYCLE_CNT_REG_CNT_LO, rdata_lo, err);
        bus_read(`CYCLE_CNT_REG_CNT_HI, rdata_hi, err);
        check_val(rdata_hi, 32'h0000_0001, "Carry into CNT_HI verified");

        // Test 8: Write to RO registers is accepted and ignored
        $display("\n--- Test 8: Write to Read-Only Registers Ignored ---");
        bus_write(`CYCLE_CNT_REG_STATUS, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to STATUS accepted without error");

        bus_write(`CYCLE_CNT_REG_CNT_LO, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to CNT_LO accepted without error");

        bus_write(`CYCLE_CNT_REG_CNT_HI, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to CNT_HI accepted without error");

        // Test 9: Undefined offset returns error response
        $display("\n--- Test 9: Undefined Offset Error Response ---");
        bus_read(8'h10, rdata, err);
        check_flag(err, 1'b1, "Read undefined offset 0x10 returns error");

        bus_read(8'h20, rdata, err);
        check_flag(err, 1'b1, "Read undefined offset 0x20 returns error");

        bus_write(8'h14, 32'h1234_5678, 4'hF, err);
        check_flag(err, 1'b1, "Write undefined offset 0x14 returns error");

        // Summary
        $display("\n=================================================");
        $display("Cycle Counter Unit Test Summary:");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=================================================");

        if (fail_count == 0) begin
            $display("[PASS] Cycle Counter Unit Tests PASSED completely.\n");
        end else begin
            $display("[FAIL] Cycle Counter Unit Tests FAILED with %0d errors.\n", fail_count);
        end

        $finish;
    end

endmodule
