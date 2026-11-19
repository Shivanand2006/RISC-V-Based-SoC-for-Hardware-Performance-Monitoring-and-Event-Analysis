// =============================================================================
// File        : cycle_cnt_driver.sv
// Description : UVM Driver for the Cycle Counter VIP.
//               Pulls sequence items from sequencer and drives the bus_if.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef CYCLE_CNT_DRIVER_SV
`define CYCLE_CNT_DRIVER_SV

class cycle_cnt_driver extends uvm_driver #(cycle_cnt_seq_item);

  `uvm_component_utils(cycle_cnt_driver)

  // ---------------------------------------------------------------------------
  // Virtual Interface Handle
  // ---------------------------------------------------------------------------
  virtual bus_if vif;

  // Base address of Cycle Counter in the SoC memory map
  parameter logic [31:0] CYCLE_CNT_BASE = 32'h0000_2300;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "cycle_cnt_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase: Get virtual interface from config_db
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF",
        "cycle_cnt_driver: No virtual bus_if found in config_db. Set it in tb_top.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase: Forever loop to drive transactions
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    cycle_cnt_seq_item req;

    // Idle bus
    vif.cb.req   <= 1'b0;
    vif.cb.we    <= 1'b0;
    vif.cb.addr  <= '0;
    vif.cb.wdata <= '0;
    vif.cb.wstrb <= 4'hF;

    // Wait for reset de-assertion
    @(posedge vif.rst_n);
    @(vif.cb);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // drive_transaction: Drive one bus transaction
  // ---------------------------------------------------------------------------
  virtual task drive_transaction(cycle_cnt_seq_item req);
    // Phase 1: Assert request
    @(vif.cb);
    vif.cb.req   <= 1'b1;
    vif.cb.we    <= req.we;
    vif.cb.addr  <= CYCLE_CNT_BASE | {24'h0, req.addr};
    vif.cb.wdata <= req.we ? req.data : 32'h0;
    vif.cb.wstrb <= req.wstrb;

    `uvm_info("DRV",
      $sformatf("Drive: addr=0x%08h we=%0b data=0x%08h",
        CYCLE_CNT_BASE | {24'h0, req.addr}, req.we, req.data),
      UVM_HIGH)

    // Phase 2: Wait for ready handshake
    begin : wait_ready
      int timeout_cnt = 0;
      while (!vif.cb.ready) begin
        @(vif.cb);
        timeout_cnt++;
        if (timeout_cnt > 100) begin
          `uvm_error("TIMEOUT",
            "cycle_cnt_driver: Bus ready not received within 100 cycles")
          break;
        end
      end
    end

    // Phase 3: Sample response
    req.rdata = vif.cb.rdata;
    req.ready = vif.cb.ready;
    req.err   = vif.cb.err;

    if (req.err) begin
      `uvm_error("BUS_ERR",
        $sformatf("Bus error on addr=0x%08h", CYCLE_CNT_BASE | {24'h0, req.addr}))
    end

    `uvm_info("DRV",
      $sformatf("Done: rdata=0x%08h err=%0b", req.rdata, req.err),
      UVM_HIGH)

    // Phase 4: Deassert request (1-cycle req/ready – deassert next cycle)
    @(vif.cb);
    vif.cb.req <= 1'b0;
    vif.cb.we  <= 1'b0;
  endtask : drive_transaction

endclass : cycle_cnt_driver

`endif // CYCLE_CNT_DRIVER_SV
