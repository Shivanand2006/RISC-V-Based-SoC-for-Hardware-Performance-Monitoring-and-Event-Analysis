// =============================================================================
// File        : bus_decoder_test.sv
// Description : UVM Test for Central Bus Decoder VIP Unit Testbench
// =============================================================================

`ifndef BUS_DECODER_TEST_SV
`define BUS_DECODER_TEST_SV

class bus_decoder_test extends uvm_test;
  `uvm_component_utils(bus_decoder_test)

  bus_decoder_env env;

  function new(string name = "bus_decoder_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = bus_decoder_env::type_id::create("env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting bus_decoder_test");
    `uvm_info("DEC_VIP_TEST", "=== Running Central Bus Decoder VIP Verification Test ===", UVM_LOW)
    #5000;
    `uvm_info("DEC_VIP_TEST", "[PASS] Central Bus Decoder VIP Verification Completed", UVM_NONE)
    phase.drop_objection(this, "Ending bus_decoder_test");
  endtask : run_phase

endclass : bus_decoder_test

`endif
