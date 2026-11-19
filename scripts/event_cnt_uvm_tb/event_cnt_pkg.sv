// =============================================================================
// File        : event_cnt_pkg.sv
// Description : UVM Package for Event Counter VIP
// =============================================================================

`ifndef EVENT_CNT_PKG_SV
`define EVENT_CNT_PKG_SV

`include "uvm_macros.svh"

package event_cnt_pkg;
  import uvm_pkg::*;

  `include "event_cnt_item.sv"
  `include "event_cnt_driver.sv"
  `include "event_cnt_monitor.sv"
  `include "event_cnt_scoreboard.sv"
  `include "event_cnt_agent.sv"
  `include "event_cnt_env.sv"
  `include "event_cnt_test.sv"

endpackage : event_cnt_pkg

`endif
