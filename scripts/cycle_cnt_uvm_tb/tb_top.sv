// =============================================================================
// File        : tb_top.sv
// Description : Standalone UVM Testbench Top for Cycle Counter VIP
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "cycle_cnt_if.sv"
`include "cycle_cnt_pkg.sv"
import cycle_cnt_pkg::*;

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

  cycle_cnt_if vif(clk, rst_n);

  cycle_cnt_top dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .bus_req_i  (vif.req),
    .bus_we_i   (vif.we),
    .bus_addr_i (vif.addr[7:0]),
    .bus_wdata_i(vif.wdata),
    .bus_wstrb_i(vif.wstrb),
    .bus_ready_o(vif.ready),
    .bus_rdata_o(vif.rdata),
    .bus_err_o  (vif.err)
  );

  initial begin
    uvm_config_db #(virtual cycle_cnt_if)::set(null, "*", "vif", vif);
    run_test("cycle_cnt_test");
  end

endmodule
