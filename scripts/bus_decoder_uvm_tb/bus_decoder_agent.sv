// =============================================================================
// File        : bus_decoder_agent.sv
// Description : UVM Agent for Central Bus Decoder VIP.
//               Instantiates sequencer, driver, and monitor based on is_active.
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_DECODER_AGENT_SV
`define BUS_DECODER_AGENT_SV

class bus_decoder_agent extends uvm_agent;

  `uvm_component_utils(bus_decoder_agent)

  uvm_sequencer #(bus_decoder_seq_item) sqr;
  bus_decoder_driver                    drv;
  bus_decoder_monitor                   mon;

  function new(string name = "bus_decoder_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = bus_decoder_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = uvm_sequencer #(bus_decoder_seq_item)::type_id::create("sqr", this);
      drv = bus_decoder_driver::type_id::create("drv", this);
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : bus_decoder_agent

`endif // BUS_DECODER_AGENT_SV
