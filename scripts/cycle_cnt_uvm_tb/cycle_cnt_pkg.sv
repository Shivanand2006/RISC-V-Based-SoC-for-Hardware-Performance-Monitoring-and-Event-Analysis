// =============================================================================
// File        : cycle_cnt_pkg.sv
// Description : UVM Package for Cycle Counter VIP
// =============================================================================

`ifndef CYCLE_CNT_PKG_SV
`define CYCLE_CNT_PKG_SV

`include "uvm_macros.svh"

package cycle_cnt_pkg;
  import uvm_pkg::*;

  `include "cycle_cnt_item.sv"
  `include "cycle_cnt_driver.sv"
  `include "cycle_cnt_monitor.sv"
  `include "cycle_cnt_scoreboard.sv"
  `include "cycle_cnt_agent.sv"
  `include "cycle_cnt_env.sv"
  `include "cycle_cnt_test.sv"

endpackage : cycle_cnt_pkg

`endif
