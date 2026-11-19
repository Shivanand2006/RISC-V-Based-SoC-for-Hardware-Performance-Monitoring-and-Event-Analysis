// =============================================================================
// File        : cycle_cnt_monitor.sv
// Description : UVM Monitor for the Cycle Counter VIP.
//               Passively samples the bus and writes captured transactions
//               to the analysis port. Includes functional coverage.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef CYCLE_CNT_MONITOR_SV
`define CYCLE_CNT_MONITOR_SV

class cycle_cnt_monitor extends uvm_monitor;

  `uvm_component_utils(cycle_cnt_monitor)

  // ---------------------------------------------------------------------------
  // Analysis Port
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(cycle_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Virtual Interface Handle
  // ---------------------------------------------------------------------------
  virtual bus_if vif;

  // Base address of Cycle Counter
  parameter logic [31:0] CYCLE_CNT_BASE = 32'h0000_2300;
  parameter logic [31:0] CYCLE_CNT_END  = 32'h0000_23FF;

  // ---------------------------------------------------------------------------
  // Functional Coverage
  // ---------------------------------------------------------------------------
  covergroup cg_cycle_cnt_access;
    cp_addr: coverpoint sampled_addr {
      bins CTRL      = {8'h00};
      bins STATUS    = {8'h04};
      bins CNT_LO    = {8'h08};
      bins CNT_HI    = {8'h0C};
    }
    cp_we: coverpoint sampled_we {
      bins READ  = {1'b0};
      bins WRITE = {1'b1};
    }
    cp_cross_addr_we: cross cp_addr, cp_we;
    cp_err: coverpoint sampled_err {
      bins NO_ERR = {1'b0};
      bins ERR    = {1'b1};
    }
  endgroup : cg_cycle_cnt_access

  // Sampled values used by covergroup
  logic [7:0] sampled_addr;
  logic       sampled_we;
  logic       sampled_err;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "cycle_cnt_monitor", uvm_component parent = null);
    super.new(name, parent);
    cg_cycle_cnt_access = new();
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF",
        "cycle_cnt_monitor: No virtual bus_if found in config_db.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase: Sample bus transactions
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    cycle_cnt_seq_item item;

    @(posedge vif.rst_n);

    forever begin
      @(vif.cb);

      // Sample when req and ready both asserted
      if (vif.cb.req && vif.cb.ready) begin
        // Check address is in Cycle Counter region
        if (vif.cb.addr >= CYCLE_CNT_BASE && vif.cb.addr <= CYCLE_CNT_END) begin
          item = cycle_cnt_seq_item::type_id::create("mon_item");

          item.addr  = vif.cb.addr[7:0];
          item.we    = vif.cb.we;
          item.data  = vif.cb.wdata;
          item.wstrb = vif.cb.wstrb;
          item.rdata = vif.cb.rdata;
          item.ready = vif.cb.ready;
          item.err   = vif.cb.err;

          // Update coverage sample points
          sampled_addr = vif.cb.addr[7:0];
          sampled_we   = vif.cb.we;
          sampled_err  = vif.cb.err;
          cg_cycle_cnt_access.sample();

          `uvm_info("MON",
            $sformatf("Captured: addr=0x%02h we=%0b rdata=0x%08h err=%0b",
              item.addr, item.we, item.rdata, item.err),
            UVM_HIGH)

          // Write to analysis port
          ap.write(item);
        end
      end
    end
  endtask : run_phase

endclass : cycle_cnt_monitor

`endif // CYCLE_CNT_MONITOR_SV
