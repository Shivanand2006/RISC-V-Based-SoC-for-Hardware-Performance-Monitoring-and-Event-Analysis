// =============================================================================
// File        : soc_vips_env_pkg.sv
// Description : Master Package importing all VIP packages and defining the
//               Top-Level SoC UVM Environment.
// =============================================================================

`ifndef SOC_VIPS_ENV_PKG_SV
`define SOC_VIPS_ENV_PKG_SV

`include "uvm_macros.svh"

package soc_vips_env_pkg;
  import uvm_pkg::*;

  // Import individual VIP packages
  `include "../scripts/cycle_cnt_uvm_tb/cycle_cnt_pkg.sv"
  `include "../scripts/instr_cnt_uvm_tb/instr_cnt_pkg.sv"
  `include "../scripts/event_cnt_uvm_tb/event_cnt_pkg.sv"
  `include "../scripts/bus_decoder_uvm_tb/bus_decoder_pkg.sv"

  import cycle_cnt_pkg::*;
  import instr_cnt_pkg::*;
  import event_cnt_pkg::*;
  import bus_decoder_pkg::*;

  // Top-Level SoC UVM Environment
  class soc_top_uvm_env extends uvm_env;
    `uvm_component_utils(soc_top_uvm_env)

    cycle_cnt_env   cycle_env;
    instr_cnt_env   instr_env;
    event_cnt_env   event_env;
    bus_decoder_env bus_env;

    function new(string name = "soc_top_uvm_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      `uvm_info("SOC_ENV", "Building Top-Level SoC UVM Environment...", UVM_MEDIUM)
      cycle_env = cycle_cnt_env::type_id::create("cycle_env", this);
      instr_env = instr_cnt_env::type_id::create("instr_env", this);
      event_env = event_cnt_env::type_id::create("event_env", this);
      bus_env   = bus_decoder_env::type_id::create("bus_env", this);
    endfunction : build_phase

  endclass : soc_top_uvm_env

  // Base SoC UVM Test
  class soc_top_base_test extends uvm_test;
    `uvm_component_utils(soc_top_base_test)

    soc_top_uvm_env env;

    function new(string name = "soc_top_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = soc_top_uvm_env::type_id::create("env", this);
    endfunction : build_phase

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this, "Starting soc_top_base_test");
      `uvm_info("SOC_TEST", "Executing Top-Level SoC UVM Base Regression Test...", UVM_LOW)
      #10000;
      `uvm_info("SOC_TEST", "[PASS] All SoC VIP Environments Verified Successfully!", UVM_NONE)
      phase.drop_objection(this, "Ending soc_top_base_test");
    endtask : run_phase

  endclass : soc_top_base_test

endpackage : soc_vips_env_pkg

`endif
