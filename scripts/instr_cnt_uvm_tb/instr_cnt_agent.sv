// =============================================================================
// File        : instr_cnt_agent.sv
// Description : UVM Agent for the Instruction Counter VIP.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef INSTR_CNT_AGENT_SV
`define INSTR_CNT_AGENT_SV

class instr_cnt_agent extends uvm_agent;

  `uvm_component_utils(instr_cnt_agent)

  // ---------------------------------------------------------------------------
  // Sub-components
  // ---------------------------------------------------------------------------
  instr_cnt_driver  drv;
  instr_cnt_monitor mon;
  uvm_sequencer #(instr_cnt_seq_item) seqr;

  // ---------------------------------------------------------------------------
  // Analysis Port (forwarded from monitor)
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(instr_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "instr_cnt_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = instr_cnt_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv  = instr_cnt_driver::type_id::create("drv", this);
      seqr = uvm_sequencer #(instr_cnt_seq_item)::type_id::create("seqr", this);
      `uvm_info("AGENT", "instr_cnt_agent: ACTIVE mode", UVM_MEDIUM)
    end else begin
      `uvm_info("AGENT", "instr_cnt_agent: PASSIVE mode", UVM_MEDIUM)
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // connect_phase
  // ---------------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    ap = mon.ap;
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : instr_cnt_agent

`endif // INSTR_CNT_AGENT_SV
