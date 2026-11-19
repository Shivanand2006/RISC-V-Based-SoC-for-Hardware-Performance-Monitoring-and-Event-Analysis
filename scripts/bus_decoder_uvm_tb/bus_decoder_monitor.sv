// =============================================================================
// File        : bus_decoder_monitor.sv
// Description : UVM Monitor for the Central Bus Decoder VIP.
//               Passively samples system bus transfers, determines targeted
//               memory/peripheral region, checks error flags, and collects coverage.
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_DECODER_MONITOR_SV
`define BUS_DECODER_MONITOR_SV

class bus_decoder_monitor extends uvm_monitor;

  `uvm_component_utils(bus_decoder_monitor)

  uvm_analysis_port #(bus_decoder_seq_item) ap;
  virtual bus_if vif;

  // Sampled variables for covergroup
  logic [31:0] cov_addr;
  logic        cov_we;
  logic        cov_err;

  // Functional Coverage
  covergroup cg_bus_decoder;
    cp_region: coverpoint cov_addr {
      bins IMEM       = {[32'h0000_0000 : 32'h0000_0FFF]};
      bins DMEM       = {[32'h0000_1000 : 32'h0000_1FFF]};
      bins UART       = {[32'h0000_2000 : 32'h0000_20FF]};
      bins TIMER      = {[32'h0000_2100 : 32'h0000_21FF]};
      bins GPIO       = {[32'h0000_2200 : 32'h0000_22FF]};
      bins CYCLE_CNT  = {[32'h0000_2300 : 32'h0000_23FF]};
      bins INSTR_CNT  = {[32'h0000_2400 : 32'h0000_24FF]};
      bins EVENT_CNT  = {[32'h0000_2500 : 32'h0000_25FF]};
      bins UNMAPPED_LOW  = {[32'h0000_2600 : 32'h0000_2FFF]};
      bins UNMAPPED_HIGH = {[32'h0000_3000 : 32'hFFFF_FFFF]};
    }
    cp_we: coverpoint cov_we {
      bins READ  = {1'b0};
      bins WRITE = {1'b1};
    }
    cp_err: coverpoint cov_err {
      bins NO_ERR = {1'b0};
      bins ERR    = {1'b1};
    }
    cross_addr_err: cross cp_region, cp_err;
  endgroup

  function new(string name = "bus_decoder_monitor", uvm_component parent = null);
    super.new(name, parent);
    cg_bus_decoder = new();
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    bus_decoder_seq_item item;

    @(posedge vif.rst_n);

    forever begin
      @(vif.cb);
      if (vif.cb.req && vif.cb.ready) begin
        item = bus_decoder_seq_item::type_id::create("item");
        item.addr  = vif.cb.addr;
        item.we    = vif.cb.we;
        item.data  = vif.cb.wdata;
        item.wstrb = vif.cb.wstrb;
        item.rdata = vif.cb.rdata;
        item.ready = vif.cb.ready;
        item.err   = vif.cb.err;

        // Sample coverage
        cov_addr = item.addr;
        cov_we   = item.we;
        cov_err  = item.err;
        cg_bus_decoder.sample();

        ap.write(item);
      end
    end
  endtask : run_phase

endclass : bus_decoder_monitor

`endif // BUS_DECODER_MONITOR_SV
