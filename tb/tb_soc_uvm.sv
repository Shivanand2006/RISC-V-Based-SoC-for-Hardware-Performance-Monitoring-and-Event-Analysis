// =============================================================================
// File        : tb_soc_uvm.sv
// Description : Top-Level SystemVerilog UVM Testbench for RISC-V HPM SoC
//               Instantiates SoC DUT, connects VIP interfaces, and executes UVM tests.
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "../scripts/cycle_cnt_uvm_tb/cycle_cnt_if.sv"
`include "../scripts/instr_cnt_uvm_tb/instr_cnt_if.sv"
`include "soc_vips_env_pkg.sv"
import soc_vips_env_pkg::*;

module tb_soc_uvm;

  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #10 clk = ~clk; // 50 MHz
  end

  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
    $display("[TB_SOC_UVM] Reset deasserted. Launching UVM testsuite...");
  end

  // Interfaces
  cycle_cnt_if   cyc_vif (clk, rst_n);
  hpm_soc_if     soc_vif (clk, rst_n);
  bus_decoder_if bus_vif (clk, rst_n);

  // Top-Level SoC DUT
  soc_top #(
    .HEX_FILE("")
  ) u_soc_top (
    .clk      (clk),
    .rst_n    (rst_n),
    .uart_rx  (soc_vif.uart_rx),
    .uart_tx  (soc_vif.uart_tx),
    .gpio_in  (soc_vif.gpio_in),
    .gpio_out (soc_vif.gpio_out)
  );

  // Wire snoop signals
  assign soc_vif.events[0] = u_soc_top.core_evt_load;
  assign soc_vif.events[1] = u_soc_top.core_evt_store;
  assign soc_vif.events[2] = u_soc_top.core_evt_fetch;
  assign soc_vif.events[3] = u_soc_top.core_evt_branch_jump;
  assign soc_vif.events[4] = u_soc_top.core_evt_stall_bubble;
  assign soc_vif.events[5] = u_soc_top.core_evt_exception;
  assign soc_vif.events[6] = u_soc_top.timer_tick;
  assign soc_vif.events[7] = u_soc_top.uart_tx_done;

  assign soc_vif.instr_retire = u_soc_top.core_instr_retire;

`ifdef FSDB
  initial begin
    $fsdbDumpfile("tb_soc_uvm.fsdb");
    $fsdbDumpvars(0, tb_soc_uvm, "+all");
    $fsdbDumpMDA();
  end
`endif

  initial begin
    uvm_config_db #(virtual cycle_cnt_if)::set(null, "*", "vif", cyc_vif);
    uvm_config_db #(virtual hpm_soc_if)::set(null, "*", "soc_vif", soc_vif);
    uvm_config_db #(virtual bus_decoder_if)::set(null, "*", "bus_vif", bus_vif);

    run_test("soc_top_base_test");
  end

endmodule
