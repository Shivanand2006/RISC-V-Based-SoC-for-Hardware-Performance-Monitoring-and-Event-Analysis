// =============================================================================
// File        : instr_cnt_env.sv
// Description : UVM Environment for Instruction Counter VIP
// =============================================================================

`ifndef INSTR_CNT_ENV_SV
`define INSTR_CNT_ENV_SV

class instr_cnt_env extends uvm_env;
  `uvm_component_utils(instr_cnt_env)

  instr_cnt_agent      agent;
  instr_cnt_scoreboard sb;

  function new(string name = "instr_cnt_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = instr_cnt_agent::type_id::create("agent", this);
    sb    = instr_cnt_scoreboard::type_id::create("sb", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.ap_imp);
  endfunction : connect_phase

endclass : instr_cnt_env

`endif
