// =============================================================================
// File        : instr_cnt_monitor.sv
// Description : UVM Monitor for the Instruction Counter VIP.
//               Monitors bus transactions AND instr_retire pulses.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef INSTR_CNT_MONITOR_SV
`define INSTR_CNT_MONITOR_SV

class instr_cnt_monitor extends uvm_monitor;

  `uvm_component_utils(instr_cnt_monitor)

  // ---------------------------------------------------------------------------
  // Analysis Port
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(instr_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Virtual Interface
  // ---------------------------------------------------------------------------
  virtual hpm_soc_if vif;

  // Address range
  parameter logic [31:0] INSTR_CNT_BASE = 32'h0000_2400;
  parameter logic [31:0] INSTR_CNT_END  = 32'h0000_24FF;

  // Observed retire pulse count
  int unsigned observed_retire_count;

  // ---------------------------------------------------------------------------
  // Functional Coverage
  // ---------------------------------------------------------------------------
  covergroup cg_instr_cnt_access;
    cp_addr: coverpoint sampled_addr {
      bins CTRL    = {8'h00};
      bins STATUS  = {8'h04};
      bins CNT_LO  = {8'h08};
      bins CNT_HI  = {8'h0C};
    }
    cp_we: coverpoint sampled_we {
      bins READ  = {1'b0};
      bins WRITE = {1'b1};
    }
    cp_retire: coverpoint sampled_retire {
      bins NO_RETIRE = {1'b0};
      bins RETIRE    = {1'b1};
    }
    cp_en: coverpoint sampled_en {
      bins DISABLED = {1'b0};
      bins ENABLED  = {1'b1};
    }
    cp_cross_retire_en: cross cp_retire, cp_en;
    cp_cross_addr_we:   cross cp_addr, cp_we;
  endgroup : cg_instr_cnt_access

  logic [7:0] sampled_addr;
  logic       sampled_we;
  logic       sampled_retire;
  logic       sampled_en;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "instr_cnt_monitor", uvm_component parent = null);
    super.new(name, parent);
    cg_instr_cnt_access    = new();
    observed_retire_count  = 0;
    sampled_en             = 1'b0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual hpm_soc_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF",
        "instr_cnt_monitor: No virtual hpm_soc_if found in config_db.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase: Parallel bus monitor and retire monitor
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);
    fork
      monitor_bus();
      monitor_retire();
    join
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // monitor_bus: Sample instruction counter bus transactions
  // ---------------------------------------------------------------------------
  virtual task monitor_bus();
    instr_cnt_seq_item item;
    forever begin
      @(vif.cb);
      if (vif.cb.bus_req && vif.cb.bus_ready) begin
        if (vif.cb.bus_addr >= INSTR_CNT_BASE &&
            vif.cb.bus_addr <= INSTR_CNT_END) begin

          item = instr_cnt_seq_item::type_id::create("mon_item");
          item.addr         = vif.cb.bus_addr[7:0];
          item.we           = vif.cb.bus_we;
          item.data         = vif.cb.bus_wdata;
          item.wstrb        = vif.cb.bus_wstrb;
          item.rdata        = vif.cb.bus_rdata;
          item.ready        = vif.cb.bus_ready;
          item.err          = vif.cb.bus_err;
          item.instr_retire = vif.cb.instr_retire;
          item.retire_count = 0;

          // Track EN from CTRL writes
          if (item.we && item.addr == 8'h00) begin
            sampled_en = item.data[0];
          end

          sampled_addr   = item.addr;
          sampled_we     = item.we;
          sampled_retire = vif.cb.instr_retire;
          cg_instr_cnt_access.sample();

          `uvm_info("INSTR_MON",
            $sformatf("Bus: addr=0x%02h we=%0b rdata=0x%08h retire=%0b",
              item.addr, item.we, item.rdata, item.instr_retire),
            UVM_HIGH)

          ap.write(item);
        end
      end
    end
  endtask : monitor_bus

  // ---------------------------------------------------------------------------
  // monitor_retire: Track all instr_retire pulses
  // ---------------------------------------------------------------------------
  virtual task monitor_retire();
    instr_cnt_seq_item retire_item;
    forever begin
      @(vif.cb);
      // Detect rising edge of instr_retire
      if (vif.cb.instr_retire === 1'b1) begin
        observed_retire_count++;

        retire_item = instr_cnt_seq_item::type_id::create("retire_item");
        retire_item.addr         = 8'hFF; // Sentinel: retire-only event
        retire_item.we           = 1'b0;
        retire_item.instr_retire = 1'b1;
        retire_item.retire_count = observed_retire_count;
        retire_item.rdata        = '0;
        retire_item.err          = 1'b0;

        // Update coverage
        sampled_retire = 1'b1;
        cg_instr_cnt_access.sample();

        `uvm_info("INSTR_MON",
          $sformatf("instr_retire pulse #%0d observed", observed_retire_count),
          UVM_HIGH)

        ap.write(retire_item);
      end
    end
  endtask : monitor_retire

endclass : instr_cnt_monitor

`endif // INSTR_CNT_MONITOR_SV
