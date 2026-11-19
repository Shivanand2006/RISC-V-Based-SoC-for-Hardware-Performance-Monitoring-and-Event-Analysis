// =============================================================================
// File        : cycle_cnt_test.sv
// Description : UVM Test for Cycle Counter VIP Unit Testbench
// =============================================================================

`ifndef CYCLE_CNT_TEST_SV
`define CYCLE_CNT_TEST_SV

class cycle_cnt_test extends uvm_test;
  `uvm_component_utils(cycle_cnt_test)

  cycle_cnt_env env;

  function new(string name = "cycle_cnt_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = cycle_cnt_env::type_id::create("env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting cycle_cnt_test");
    `uvm_info("CYC_VIP_TEST", "=== Running Cycle Counter VIP Verification Test ===", UVM_LOW)
    #5000;
    `uvm_info("CYC_VIP_TEST", "[PASS] Cycle Counter VIP Verification Completed", UVM_NONE)
    phase.drop_objection(this, "Ending cycle_cnt_test");
  endtask : run_phase

endclass : cycle_cnt_test

`endif
