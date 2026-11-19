// =============================================================================
// File        : tb_top.sv
// Description : Standalone UVM Testbench Top for Instruction Counter VIP
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "instr_cnt_if.sv"
`include "instr_cnt_pkg.sv"
import instr_cnt_pkg::*;

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

  instr_cnt_top dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .instr_retire_i(vif.instr_retire),
    .bus_req_i     (vif.bus_req),
    .bus_we_i      (vif.bus_we),
    .bus_addr_i    (vif.bus_addr[7:0]),
    .bus_wdata_i   (vif.bus_wdata),
    .bus_wstrb_i   (vif.bus_wstrb),
    .bus_ready_o   (vif.bus_ready),
    .bus_rdata_o   (vif.bus_rdata),
    .bus_err_o     (vif.bus_err)
  );

  initial begin
    uvm_config_db #(virtual hpm_soc_if)::set(null, "*", "vif", vif);
    run_test("instr_cnt_test");
  end

endmodule
