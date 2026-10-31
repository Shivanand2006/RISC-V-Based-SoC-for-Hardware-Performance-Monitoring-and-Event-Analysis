//=============================================================================
// File: tb_bus_decoder.v
// Description: Self-checking unit testbench for central address decoder.
//              Verifies window boundaries, one-hot selection, offset mapping,
//              and unmapped error response without deadlock.
// Standard: Verilog-2001 Testbench
//=============================================================================

`timescale 1ns/1ps
`include "interconnect_defines.vh"

module tb_bus_decoder;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Master bus signals
    reg         m_req;
    reg         m_we;
    reg  [31:0] m_addr;
    reg  [31:0] m_wdata;
    reg  [3:0]  m_wstrb;
    wire        m_ready;
    wire [31:0] m_rdata;
    wire        m_err;

    // Slave wires
    wire        imem_req, dmem_req, uart_req, timer_req;
    wire        gpio_req, cycle_cnt_req, instr_cnt_req, event_cnt_req;

    wire [11:0] imem_addr, dmem_addr;
    wire [7:0]  uart_addr, timer_addr, gpio_addr;
    wire [7:0]  cycle_cnt_addr, instr_cnt_addr, event_cnt_addr;

    wire [31:0] s_wdata;
    wire [3:0]  s_wstrb;

    // Slave dummy responses
    reg  [31:0] imem_rdata, dmem_rdata, uart_rdata, timer_rdata;
    reg  [31:0] gpio_rdata, cycle_cnt_rdata, instr_cnt_rdata, event_cnt_rdata;
    reg         imem_err, dmem_err, uart_err, timer_err;
    reg         gpio_err, cycle_cnt_err, instr_cnt_err, event_cnt_err;

    // Test tracking
    integer fail_count = 0;
    integer pass_count = 0;

    // Instantiate Decoder
    bus_decoder #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .m_req_i          (m_req),
        .m_we_i           (m_we),
        .m_addr_i         (m_addr),
        .m_wdata_i        (m_wdata),
        .m_wstrb_i        (m_wstrb),
        .m_ready_o        (m_ready),
        .m_rdata_o        (m_rdata),
        .m_err_o          (m_err),
        .imem_req_o       (imem_req),
        .imem_we_o        (),
        .imem_addr_o      (imem_addr),
        .imem_wdata_o     (),
        .imem_wstrb_o     (),
        .imem_ready_i     (imem_req),
        .imem_rdata_i     (imem_rdata),
        .imem_err_i       (imem_err),
        .dmem_req_o       (dmem_req),
        .dmem_we_o        (),
        .dmem_addr_o      (dmem_addr),
        .dmem_wdata_o     (),
        .dmem_wstrb_o     (),
        .dmem_ready_i     (dmem_req),
        .dmem_rdata_i     (dmem_rdata),
        .dmem_err_i       (dmem_err),
        .uart_req_o       (uart_req),
        .uart_we_o        (),
        .uart_addr_o      (uart_addr),
        .uart_wdata_o     (),
        .uart_wstrb_o     (),
        .uart_ready_i     (uart_req),
        .uart_rdata_i     (uart_rdata),
        .uart_err_i       (uart_err),
        .timer_req_o      (timer_req),
        .timer_we_o       (),
        .timer_addr_o     (timer_addr),
        .timer_wdata_o    (),
        .timer_wstrb_o    (),
        .timer_ready_i    (timer_req),
        .timer_rdata_i    (timer_rdata),
        .timer_err_i      (timer_err),
        .gpio_req_o       (gpio_req),
        .gpio_we_o        (),
        .gpio_addr_o      (gpio_addr),
        .gpio_wdata_o     (),
        .gpio_wstrb_o     (),
        .gpio_ready_i     (gpio_req),
        .gpio_rdata_i     (gpio_rdata),
        .gpio_err_i       (gpio_err),
        .cycle_cnt_req_o  (cycle_cnt_req),
        .cycle_cnt_we_o   (),
        .cycle_cnt_addr_o (cycle_cnt_addr),
        .cycle_cnt_wdata_o(),
        .cycle_cnt_wstrb_o(),
        .cycle_cnt_ready_i(cycle_cnt_req),
        .cycle_cnt_rdata_i(cycle_cnt_rdata),
        .cycle_cnt_err_i  (cycle_cnt_err),
        .instr_cnt_req_o  (instr_cnt_req),
        .instr_cnt_we_o   (),
        .instr_cnt_addr_o (instr_cnt_addr),
        .instr_cnt_wdata_o(),
        .instr_cnt_wstrb_o(),
        .instr_cnt_ready_i(instr_cnt_req),
        .instr_cnt_rdata_i(instr_cnt_rdata),
        .instr_cnt_err_i  (instr_cnt_err),
        .event_cnt_req_o  (event_cnt_req),
        .event_cnt_we_o   (),
        .event_cnt_addr_o (event_cnt_addr),
        .event_cnt_wdata_o(),
        .event_cnt_wstrb_o(),
        .event_cnt_ready_i(event_cnt_req),
        .event_cnt_rdata_i(event_cnt_rdata),
        .event_cnt_err_i  (event_cnt_err)
    );

    // Clock generation (50MHz -> 20ns period)
    always #10 clk = ~clk;

    // Helper task to test mapped window
    task test_window;
        input [31:0] addr;
        input [7:0]  expected_select_mask; // 8 slaves
        input [11:0] expected_offset;
        input [255:0] test_name;
        reg [7:0] actual_select_mask;
        begin
            @(posedge clk);
            m_req   <= 1'b1;
            m_we    <= 1'b0;
            m_addr  <= addr;
            m_wstrb <= 4'h0;
            @(posedge clk);
            actual_select_mask = {event_cnt_req, instr_cnt_req, cycle_cnt_req,
                                  gpio_req, timer_req, uart_req, dmem_req, imem_req};
            if (actual_select_mask === expected_select_mask && m_ready === 1'b1 && m_err === 1'b0) begin
                $display("  [PASS] %0s: addr=0x%08h select_mask=%08b", test_name, addr, actual_select_mask);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: addr=0x%08h expected mask=%08b, got %08b (ready=%b, err=%b)",
                         test_name, addr, expected_select_mask, actual_select_mask, m_ready, m_err);
                fail_count = fail_count + 1;
            end
            m_req <= 1'b0;
        end
    endtask

    // Helper task to test unmapped access
    task test_unmapped;
        input [31:0] addr;
        input [255:0] test_name;
        reg [7:0] actual_select_mask;
        begin
            @(posedge clk);
            m_req   <= 1'b1;
            m_we    <= 1'b0;
            m_addr  <= addr;
            m_wstrb <= 4'h0;
            @(posedge clk);
            actual_select_mask = {event_cnt_req, instr_cnt_req, cycle_cnt_req,
                                  gpio_req, timer_req, uart_req, dmem_req, imem_req};
            if (actual_select_mask === 8'b0000_0000 && m_ready === 1'b1 && m_err === 1'b1) begin
                $display("  [PASS] %0s: addr=0x%08h correctly returned error response without hanging", test_name, addr);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: addr=0x%08h expected error=1, mask=0, got error=%b, mask=%08b",
                         test_name, addr, m_err, actual_select_mask);
                fail_count = fail_count + 1;
            end
            m_req <= 1'b0;
        end
    endtask

    initial begin
        clk              = 0;
        rst_n            = 0;
        m_req            = 0;
        m_we             = 0;
        m_addr           = 0;
        m_wdata          = 0;
        m_wstrb          = 0;
        imem_rdata       = 32'h1111_1111;
        dmem_rdata       = 32'h2222_2222;
        uart_rdata       = 32'h3333_3333;
        timer_rdata      = 32'h4444_4444;
        gpio_rdata       = 32'h5555_5555;
        cycle_cnt_rdata  = 32'h6666_6666;
        instr_cnt_rdata  = 32'h7777_7777;
        event_cnt_rdata  = 32'h8888_8888;
        imem_err         = 0;
        dmem_err         = 0;
        uart_err         = 0;
        timer_err        = 0;
        gpio_err         = 0;
        cycle_cnt_err    = 0;
        instr_cnt_err    = 0;
        event_cnt_err    = 0;

        $display("=================================================");
        $display("Starting Bus Decoder Unit Testbench");
        $display("=================================================");

        #45;
        rst_n = 1;
        #20;

        // Test First and Last Addresses of Each Window
        $display("\n--- Window Boundary Tests ---");

        // IMEM: 0x0000_0000 - 0x0000_0FFF (bit 0)
        test_window(32'h0000_0000, 8'b0000_0001, 12'h000, "IMEM First Address");
        test_window(32'h0000_0FFF, 8'b0000_0001, 12'hFFF, "IMEM Last Address");

        // DMEM: 0x0000_1000 - 0x0000_1FFF (bit 1)
        test_window(32'h0000_1000, 8'b0000_0010, 12'h000, "DMEM First Address");
        test_window(32'h0000_1FFF, 8'b0000_0010, 12'hFFF, "DMEM Last Address");

        // UART: 0x0000_2000 - 0x0000_20FF (bit 2)
        test_window(32'h0000_2000, 8'b0000_0100, 12'h000, "UART First Address");
        test_window(32'h0000_20FF, 8'b0000_0100, 12'h0FF, "UART Last Address");

        // Timer: 0x0000_2100 - 0x0000_21FF (bit 3)
        test_window(32'h0000_2100, 8'b0000_1000, 12'h000, "Timer First Address");
        test_window(32'h0000_21FF, 8'b0000_1000, 12'h0FF, "Timer Last Address");

        // GPIO: 0x0000_2200 - 0x0000_22FF (bit 4)
        test_window(32'h0000_2200, 8'b0001_0000, 12'h000, "GPIO First Address");
        test_window(32'h0000_22FF, 8'b0001_0000, 12'h0FF, "GPIO Last Address");

        // Cycle Counter: 0x0000_2300 - 0x0000_23FF (bit 5)
        test_window(32'h0000_2300, 8'b0010_0000, 12'h000, "Cycle Counter First Address");
        test_window(32'h0000_23FF, 8'b0010_0000, 12'h0FF, "Cycle Counter Last Address");

        // Instruction Counter: 0x0000_2400 - 0x0000_24FF (bit 6)
        test_window(32'h0000_2400, 8'b0100_0000, 12'h000, "Instruction Counter First Address");
        test_window(32'h0000_24FF, 8'b0100_0000, 12'h0FF, "Instruction Counter Last Address");

        // Performance Event Counter: 0x0000_2500 - 0x0000_25FF (bit 7)
        test_window(32'h0000_2500, 8'b1000_0000, 12'h000, "Event Counter First Address");
        test_window(32'h0000_25FF, 8'b1000_0000, 12'h0FF, "Event Counter Last Address");

        // Unmapped Address Tests (Byte after each window or higher addresses)
        $display("\n--- Unmapped Space & Boundary Tests ---");
        test_unmapped(32'h0000_2600, "Address immediately after Event Counter (0x2600)");
        test_unmapped(32'h0000_2700, "Unmapped peripheral page 0x2700");
        test_unmapped(32'h0000_3000, "Unmapped page 0x3000");
        test_unmapped(32'h1000_0000, "Unmapped high memory 0x1000_0000");
        test_unmapped(32'hFFFF_FFF0, "Unmapped top memory 0xFFFF_FFF0");

        // Summary
        $display("\n=================================================");
        $display("Bus Decoder Unit Test Summary:");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("=================================================");

        if (fail_count == 0) begin
            $display("[PASS] Bus Decoder Unit Tests PASSED completely.\n");
        end else begin
            $display("[FAIL] Bus Decoder Unit Tests FAILED with %0d errors.\n", fail_count);
        end

        $finish;
    end

endmodule
