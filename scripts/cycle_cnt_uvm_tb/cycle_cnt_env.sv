// =============================================================================
// File        : cycle_cnt_env.sv
// Description : UVM Environment for Cycle Counter VIP
// =============================================================================

`ifndef CYCLE_CNT_ENV_SV
`define CYCLE_CNT_ENV_SV

class cycle_cnt_env extends uvm_env;
  `uvm_component_utils(cycle_cnt_env)

  cycle_cnt_agent      agent;
  cycle_cnt_scoreboard sb;

  function new(string name = "cycle_cnt_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = cycle_cnt_agent::type_id::create("agent", this);
    sb    = cycle_cnt_scoreboard::type_id::create("sb", this);
  endfunction : build_phase

endclass : cycle_cnt_env

`endif
