// =============================================================================
// File        : bus_if.sv
// Description : SystemVerilog interface for the simple internal single-master
//               1-cycle req/ready bus used in the HPM SoC.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_IF_SV
`define BUS_IF_SV

interface bus_if (input logic clk, input logic rst_n);

  // ---------------------------------------------------------------------------
  // Bus Signals
  // ---------------------------------------------------------------------------
  logic        req;
  logic        we;
  logic [31:0] addr;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        ready;
  logic [31:0] rdata;
  logic        err;

  // ---------------------------------------------------------------------------
  // Clocking Block – 1-step input sample delay, 1 ns output skew
  // ---------------------------------------------------------------------------
  clocking cb @(posedge clk);
    default input #1step output #1ns;
    output req;
    output we;
    output addr;
    output wdata;
    output wstrb;
    input  ready;
    input  rdata;
    input  err;
  endclocking : cb

  // ---------------------------------------------------------------------------
  // Modport: Master (testbench drives bus)
  // ---------------------------------------------------------------------------
  modport master (
    clocking cb,
    input  clk,
    input  rst_n,
    output req,
    output we,
    output addr,
    output wdata,
    output wstrb,
    input  ready,
    input  rdata,
    input  err
  );

  // ---------------------------------------------------------------------------
  // Modport: Slave (DUT receives bus)
  // ---------------------------------------------------------------------------
  modport slave (
    input  clk,
    input  rst_n,
    input  req,
    input  we,
    input  addr,
    input  wdata,
    input  wstrb,
    output ready,
    output rdata,
    output err
  );

  // ---------------------------------------------------------------------------
  // Modport: Monitor (passive observation)
  // ---------------------------------------------------------------------------
  modport monitor (
    clocking cb,
    input clk,
    input rst_n,
    input req,
    input we,
    input addr,
    input wdata,
    input wstrb,
    input ready,
    input rdata,
    input err
  );

endinterface : bus_if

`endif // BUS_IF_SV
