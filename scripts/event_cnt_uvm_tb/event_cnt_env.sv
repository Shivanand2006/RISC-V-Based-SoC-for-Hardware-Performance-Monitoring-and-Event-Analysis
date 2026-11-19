// =============================================================================
// File        : event_cnt_env.sv
// Description : UVM Environment for Event Counter VIP
// =============================================================================

`ifndef EVENT_CNT_ENV_SV
`define EVENT_CNT_ENV_SV

class event_cnt_env extends uvm_env;
  `uvm_component_utils(event_cnt_env)

  event_cnt_agent      agent;
  event_cnt_scoreboard sb;

  function new(string name = "event_cnt_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = event_cnt_agent::type_id::create("agent", this);
    sb    = event_cnt_scoreboard::type_id::create("sb", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.ap_imp);
  endfunction : connect_phase

endclass : event_cnt_env

`endif
