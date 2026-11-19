// =============================================================================
// File        : bus_decoder_driver.sv
// Description : UVM Driver for the Central Bus Decoder VIP.
//               Drives single-cycle bus requests across address spaces
//               and samples slave ready, rdata, and err responses.
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_DECODER_DRIVER_SV
`define BUS_DECODER_DRIVER_SV

class bus_decoder_driver extends uvm_driver #(bus_decoder_seq_item);

  `uvm_component_utils(bus_decoder_driver)

  // Virtual interface handle
  virtual bus_if vif;

  function new(string name = "bus_decoder_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    // Reset signals on startup
    vif.cb.req   <= 1'b0;
    vif.cb.we    <= 1'b0;
    vif.cb.addr  <= 32'h0;
    vif.cb.wdata <= 32'h0;
    vif.cb.wstrb <= 4'h0;

    @(posedge vif.rst_n);
    @(vif.cb);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask : run_phase

  virtual task drive_transaction(bus_decoder_seq_item item);
    // Drive request
    @(vif.cb);
    vif.cb.req   <= 1'b1;
    vif.cb.we    <= item.we;
    vif.cb.addr  <= item.addr;
    vif.cb.wdata <= item.data;
    vif.cb.wstrb <= item.wstrb;

    // Wait for handshake
    do begin
      @(vif.cb);
    end while (!vif.cb.ready);

    // Sample responses
    item.rdata = vif.cb.rdata;
    item.ready = vif.cb.ready;
    item.err   = vif.cb.err;

    // Deassert request
    vif.cb.req <= 1'b0;
    vif.cb.we  <= 1'b0;
  endtask : drive_transaction

endclass : bus_decoder_driver

`endif // BUS_DECODER_DRIVER_SV
