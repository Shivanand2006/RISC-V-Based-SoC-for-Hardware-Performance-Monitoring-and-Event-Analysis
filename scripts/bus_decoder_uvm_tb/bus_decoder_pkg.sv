// =============================================================================
// File        : bus_decoder_pkg.sv
// Description : UVM Package for Central Bus Decoder VIP
// =============================================================================

`ifndef BUS_DECODER_PKG_SV
`define BUS_DECODER_PKG_SV

`include "uvm_macros.svh"

package bus_decoder_pkg;
  import uvm_pkg::*;

  `include "bus_decoder_item.sv"
  `include "bus_decoder_driver.sv"
  `include "bus_decoder_monitor.sv"
  `include "bus_decoder_scoreboard.sv"
  `include "bus_decoder_agent.sv"
  `include "bus_decoder_env.sv"
  `include "bus_decoder_test.sv"

endpackage : bus_decoder_pkg

`endif
