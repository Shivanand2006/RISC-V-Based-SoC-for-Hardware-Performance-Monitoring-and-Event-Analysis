// =============================================================================
// File        : bus_decoder_env.sv
// Description : UVM Environment for Central Bus Decoder VIP
// =============================================================================

`ifndef BUS_DECODER_ENV_SV
`define BUS_DECODER_ENV_SV

class bus_decoder_env extends uvm_env;
  `uvm_component_utils(bus_decoder_env)

  bus_decoder_agent      agent;
  bus_decoder_scoreboard sb;

  function new(string name = "bus_decoder_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = bus_decoder_agent::type_id::create("agent", this);
    sb    = bus_decoder_scoreboard::type_id::create("sb", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.ap_imp);
  endfunction : connect_phase

endclass : bus_decoder_env

`endif
