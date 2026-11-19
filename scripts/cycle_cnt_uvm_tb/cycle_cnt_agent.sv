// =============================================================================
// File        : cycle_cnt_agent.sv
// Description : UVM Agent for the Cycle Counter VIP.
//               Contains driver, monitor, and sequencer. Driver and sequencer
//               are only created when is_active == UVM_ACTIVE.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef CYCLE_CNT_AGENT_SV
`define CYCLE_CNT_AGENT_SV

class cycle_cnt_agent extends uvm_agent;

  `uvm_component_utils(cycle_cnt_agent)

  // ---------------------------------------------------------------------------
  // Sub-components
  // ---------------------------------------------------------------------------
  cycle_cnt_driver    drv;
  cycle_cnt_monitor   mon;
  uvm_sequencer #(cycle_cnt_seq_item) seqr;

  // ---------------------------------------------------------------------------
  // Analysis Port (forwarded from monitor)
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(cycle_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "cycle_cnt_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase: Construct sub-components
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always instantiated (active or passive)
    mon = cycle_cnt_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv  = cycle_cnt_driver::type_id::create("drv", this);
      seqr = uvm_sequencer #(cycle_cnt_seq_item)::type_id::create("seqr", this);
      `uvm_info("AGENT", "cycle_cnt_agent: Running in ACTIVE mode", UVM_MEDIUM)
    end else begin
      `uvm_info("AGENT", "cycle_cnt_agent: Running in PASSIVE mode", UVM_MEDIUM)
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // connect_phase: Wire up TLM connections
  // ---------------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    // Forward monitor's analysis port
    ap = mon.ap;

    if (get_is_active() == UVM_ACTIVE) begin
      // Connect driver's seq_item_port to sequencer's seq_item_export
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : cycle_cnt_agent

`endif // CYCLE_CNT_AGENT_SV
