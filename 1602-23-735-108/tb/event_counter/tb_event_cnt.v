//=============================================================================
// File: tb_event_cnt.v
// Description: Self-checking unit testbench for Performance Event Counter IP.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps
`include "event_cnt_defines.vh"

module tb_event_cnt;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Event lines
    reg [7:0] events;
    wire      irq;

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
    event_cnt_top #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32),
        .STRB_WIDTH(4),
        .NUM_EVENTS(8)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .events_i   (events),
        .irq_o      (irq),
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

    // Pulse event task (1-cycle pulse)
    task pulse_event;
        input [2:0] evt_idx;
        begin
            @(posedge clk);
            events[evt_idx] <= 1'b1;
            @(posedge clk);
            events[evt_idx] <= 1'b0;
        end
    endtask

    reg [31:0] rdata;
    reg        err;
    integer    e;

    initial begin
        clk       = 0;
        rst_n     = 0;
        events    = 8'h00;
        bus_req   = 0;
        bus_we    = 0;
        bus_addr  = 0;
        bus_wdata = 0;
        bus_wstrb = 0;

        $display("=================================================");
        $display("Starting Performance Event Counter Unit Testbench");
        $display("=================================================");

        // Reset sequence
        #45;
        rst_n = 1;
        #20;

        // Test 1: Reset defaults
        $display("\n--- Test 1: Check Reset Defaults ---");
        bus_read(`EVENT_CNT_REG_CTRL, rdata, err);
        check_val(rdata, 32'h0, "Reset CTRL register");
        check_flag(err, 1'b0, "Reset CTRL no error");

        bus_read(`EVENT_CNT_REG_EVT_SEL, rdata, err);
        check_val(rdata, 32'h0, "Reset EVT_SEL register");

        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'h0, "Reset COUNT register");

        bus_read(`EVENT_CNT_REG_THRESH, rdata, err);
        check_val(rdata, 32'h0, "Reset THRESH register");

        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_val(rdata, 32'h0, "Reset STATUS register");

        check_flag(irq, 1'b0, "Reset IRQ output");

        // Test 2: Verify each of 8 event selects counts only its own pulse
        $display("\n--- Test 2: Event Select Isolation (8 Events) ---");
        bus_write(`EVENT_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN = 1

        for (e = 0; e < 8; e = e + 1) begin
            // Select event e
            bus_write(`EVENT_CNT_REG_EVT_SEL, e[31:0], 4'hF, err);
            // Clear count
            bus_write(`EVENT_CNT_REG_CTRL, 32'h3, 4'hF, err); // EN=1, CLEAR=1

            // Pulse an unselected event (e.g. (e+1)%8)
            pulse_event((e + 1) % 8);
            bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
            check_val(rdata, 32'd0, "Unselected event pulse does not increment");

            // Pulse selected event e
            pulse_event(e[2:0]);
            bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
            check_val(rdata, 32'd1, "Selected event pulse increments");
        end

        // Test 3: Threshold compare, sticky and re-arm
        $display("\n--- Test 3: Threshold Compare, Sticky and Re-arm ---");
        bus_write(`EVENT_CNT_REG_EVT_SEL, 32'd0, 4'hF, err);
        bus_write(`EVENT_CNT_REG_CTRL, 32'h3, 4'hF, err);    // Clear count
        bus_write(`EVENT_CNT_REG_THRESH, 32'd4, 4'hF, err);  // THRESH = 4

        // 3 pulses -> not yet at threshold
        repeat (3) pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'd3, "Count = 3");
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b0, "THRESH_HIT not asserted before threshold");

        // 4th pulse -> hits threshold
        pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b1, "THRESH_HIT asserted upon count >= THRESH");

        // Clear THRESH_HIT via W1C (write bit 1 = 1)
        bus_write(`EVENT_CNT_REG_STATUS, 32'h2, 4'hF, err);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b0, "THRESH_HIT cleared by W1C");

        // 5th pulse -> re-arms THRESH_HIT on next counted event
        pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b1, "THRESH_HIT re-arms on subsequent event");

        // Test 4: W1C vs Simultaneous Event Priority
        $display("\n--- Test 4: W1C vs Simultaneous Event Priority ---");
        // Clear THRESH_HIT first
        bus_write(`EVENT_CNT_REG_STATUS, 32'h2, 4'hF, err);
        // Simultaneously write W1C to STATUS bit 1 and pulse event 0
        @(posedge clk);
        bus_req   <= 1'b1;
        bus_we    <= 1'b1;
        bus_addr  <= `EVENT_CNT_REG_STATUS;
        bus_wdata <= 32'h2;
        bus_wstrb <= 4'hF;
        events[0] <= 1'b1; // Simultaneous event!
        @(posedge clk);
        bus_req   <= 1'b0;
        bus_we    <= 1'b0;
        events[0] <= 1'b0;
        @(posedge clk);

        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b1, "Simultaneous event wins over W1C clear");

        // Test 5: Overflow flag (OVF) past 0xFFFF_FFFF
        $display("\n--- Test 5: Overflow Flag Sticky Past 0xFFFF_FFFF ---");
        dut.preload_count(32'hFFFF_FFFF);
        pulse_event(3'd0); // Wraps to 0
        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'h0, "COUNT wrapped to 0");
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_OVF_BIT], 1'b1, "OVF flag asserted");

        // Clear OVF via W1C (write bit 0 = 1)
        bus_write(`EVENT_CNT_REG_STATUS, 32'h1, 4'hF, err);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_OVF_BIT], 1'b0, "OVF flag cleared by W1C");

        // Test 6: IRQ_EN gating of irq_o
        $display("\n--- Test 6: IRQ_EN Gating of irq_o ---");
        // Make sure THRESH_HIT is 1
        bus_write(`EVENT_CNT_REG_THRESH, 32'd1, 4'hF, err);
        pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b1, "THRESH_HIT is 1");

        // When IRQ_EN = 0: irq_o must be 0
        bus_write(`EVENT_CNT_REG_CTRL, 32'h1, 4'hF, err); // EN=1, IRQ_EN=0
        check_flag(irq, 1'b0, "irq_o is 0 when IRQ_EN is 0");

        // When IRQ_EN = 1: irq_o must be 1
        bus_write(`EVENT_CNT_REG_CTRL, 32'h5, 4'hF, err); // EN=1, IRQ_EN=1 (bit 2)
        check_flag(irq, 1'b1, "irq_o is 1 when IRQ_EN is 1");

        // Test 7: CLEAR clears COUNT, OVF, and THRESH_HIT
        $display("\n--- Test 7: CLEAR Clears All Flags and Count ---");
        // We currently have COUNT > 0, THRESH_HIT = 1. Let's set OVF as well.
        dut.preload_count(32'hFFFF_FFFF);
        pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_OVF_BIT], 1'b1, "Pre-condition: OVF is 1");
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b1, "Pre-condition: THRESH_HIT is 1");

        // Write CLEAR bit (bit 1)
        bus_write(`EVENT_CNT_REG_CTRL, 32'h3, 4'hF, err);
        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'h0, "COUNT cleared by CLEAR");
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_OVF_BIT], 1'b0, "OVF cleared by CLEAR");
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b0, "THRESH_HIT cleared by CLEAR");

        // Test 8: Threshold 0 disables compare
        $display("\n--- Test 8: Threshold 0 Disables Compare ---");
        bus_write(`EVENT_CNT_REG_THRESH, 32'd0, 4'hF, err); // THRESH = 0
        repeat (10) pulse_event(3'd0);
        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'd10, "COUNT incremented to 10");
        bus_read(`EVENT_CNT_REG_STATUS, rdata, err);
        check_flag(rdata[`EVENT_CNT_STATUS_THRHIT_BIT], 1'b0, "THRESH_HIT remains 0 with THRESH=0");

        // Test 9: Write to RO COUNT ignored & undefined offset error
        $display("\n--- Test 9: RO Register & Undefined Offset Checks ---");
        bus_write(`EVENT_CNT_REG_COUNT, 32'hDEAD_BEEF, 4'hF, err);
        check_flag(err, 1'b0, "Write to RO COUNT accepted without error");
        bus_read(`EVENT_CNT_REG_COUNT, rdata, err);
        check_val(rdata, 32'd10, "COUNT value unaffected by write");

        bus_read(8'h14, rdata, err);
        check_flag(err, 1'b1, "Read undefined offset 0x14 returns error");
        bus_write(8'h18, 32'h0, 4'hF, err);
        check_flag(err, 1'b1, "Write undefined offset 0x18 returns error");

        // Summary
        $display("\n=================================================");
        $display("Performance Event Counter Unit Test Summary:");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=================================================");

        if (fail_count == 0) begin
            $display("[PASS] Event Counter Unit Tests PASSED completely.\n");
        end else begin
            $display("[FAIL] Event Counter Unit Tests FAILED with %0d errors.\n", fail_count);
        end

        $finish;
    end

endmodule
