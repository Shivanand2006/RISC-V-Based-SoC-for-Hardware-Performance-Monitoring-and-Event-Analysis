// =============================================================================
// File        : tb_top.sv
// Description : Standalone UVM Testbench Top for Event Counter VIP
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "event_cnt_if.sv"
`include "event_cnt_pkg.sv"
import event_cnt_pkg::*;

module tb_top;

  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end

  hpm_soc_if vif(clk, rst_n);

  event_cnt_top #(
    .ADDR_WIDTH(8),
    .DATA_WIDTH(32),
    .STRB_WIDTH(4),
    .NUM_EVENTS(8)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .events_i   (vif.events),
    .irq_o      (vif.event_cnt_irq),
    .bus_req_i  (vif.bus_req),
    .bus_we_i   (vif.bus_we),
    .bus_addr_i (vif.bus_addr[7:0]),
    .bus_wdata_i(vif.bus_wdata),
    .bus_wstrb_i(vif.bus_wstrb),
    .bus_ready_o(vif.bus_ready),
    .bus_rdata_o(vif.bus_rdata),
    .bus_err_o  (vif.bus_err)
  );

  initial begin
    uvm_config_db #(virtual hpm_soc_if)::set(null, "*", "vif", vif);
    run_test("event_cnt_test");
  end

endmodule
