// =============================================================================
// File        : event_cnt_agent.sv
// Description : UVM Agent for the Event Counter VIP.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef EVENT_CNT_AGENT_SV
`define EVENT_CNT_AGENT_SV

class event_cnt_agent extends uvm_agent;

  `uvm_component_utils(event_cnt_agent)

  // ---------------------------------------------------------------------------
  // Sub-components
  // ---------------------------------------------------------------------------
  event_cnt_driver  drv;
  event_cnt_monitor mon;
  uvm_sequencer #(event_cnt_seq_item) seqr;

  // ---------------------------------------------------------------------------
  // Analysis Port (forwarded from monitor)
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(event_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "event_cnt_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = event_cnt_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv  = event_cnt_driver::type_id::create("drv", this);
      seqr = uvm_sequencer #(event_cnt_seq_item)::type_id::create("seqr", this);
      `uvm_info("AGENT", "event_cnt_agent: ACTIVE mode", UVM_MEDIUM)
    end else begin
      `uvm_info("AGENT", "event_cnt_agent: PASSIVE mode", UVM_MEDIUM)
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

endclass : event_cnt_agent

`endif // EVENT_CNT_AGENT_SV
