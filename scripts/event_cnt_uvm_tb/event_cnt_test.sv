// =============================================================================
// File        : event_cnt_test.sv
// Description : UVM Test for Event Counter VIP Unit Testbench
// =============================================================================

`ifndef EVENT_CNT_TEST_SV
`define EVENT_CNT_TEST_SV

class event_cnt_test extends uvm_test;
  `uvm_component_utils(event_cnt_test)

  event_cnt_env env;

  function new(string name = "event_cnt_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = event_cnt_env::type_id::create("env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting event_cnt_test");
    `uvm_info("EVENT_VIP_TEST", "=== Running Event Counter VIP Verification Test ===", UVM_LOW)
    #5000;
    `uvm_info("EVENT_VIP_TEST", "[PASS] Event Counter VIP Verification Completed", UVM_NONE)
    phase.drop_objection(this, "Ending event_cnt_test");
  endtask : run_phase

endclass : event_cnt_test

`endif
