// =============================================================================
// File        : tb_top.sv
// Description : Standalone UVM Testbench Top for Central Bus Decoder VIP
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "bus_decoder_if.sv"
`include "bus_decoder_pkg.sv"
import bus_decoder_pkg::*;

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

  bus_decoder_if vif(clk, rst_n);

  bus_decoder dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .s_req_i      (vif.req),
    .s_we_i       (vif.we),
    .s_addr_i     (vif.addr),
    .s_wdata_i    (vif.wdata),
    .s_wstrb_i    (vif.wstrb),
    .s_ready_o    (vif.ready),
    .s_rdata_o    (vif.rdata),
    .s_err_o      (vif.err)
  );

  initial begin
    uvm_config_db #(virtual bus_decoder_if)::set(null, "*", "vif", vif);
    run_test("bus_decoder_test");
  end

endmodule
