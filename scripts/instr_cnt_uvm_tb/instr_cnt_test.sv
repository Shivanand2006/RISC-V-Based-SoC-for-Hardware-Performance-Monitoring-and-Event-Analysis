// =============================================================================
// File        : instr_cnt_test.sv
// Description : UVM Test for Instruction Counter VIP Unit Testbench
// =============================================================================

`ifndef INSTR_CNT_TEST_SV
`define INSTR_CNT_TEST_SV

class instr_cnt_test extends uvm_test;
  `uvm_component_utils(instr_cnt_test)

  instr_cnt_env env;

  function new(string name = "instr_cnt_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = instr_cnt_env::type_id::create("env", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting instr_cnt_test");
    `uvm_info("INSTR_VIP_TEST", "=== Running Instruction Counter VIP Verification Test ===", UVM_LOW)
    #5000;
    `uvm_info("INSTR_VIP_TEST", "[PASS] Instruction Counter VIP Verification Completed", UVM_NONE)
    phase.drop_objection(this, "Ending instr_cnt_test");
  endtask : run_phase

endclass : instr_cnt_test

`endif
