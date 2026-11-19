// =============================================================================
// File        : instr_cnt_pkg.sv
// Description : UVM Package for Instruction Counter VIP
// =============================================================================

`ifndef INSTR_CNT_PKG_SV
`define INSTR_CNT_PKG_SV

`include "uvm_macros.svh"

package instr_cnt_pkg;
  import uvm_pkg::*;

  `include "instr_cnt_item.sv"
  `include "instr_cnt_driver.sv"
  `include "instr_cnt_monitor.sv"
  `include "instr_cnt_scoreboard.sv"
  `include "instr_cnt_agent.sv"
  `include "instr_cnt_env.sv"
  `include "instr_cnt_test.sv"

endpackage : instr_cnt_pkg

`endif
