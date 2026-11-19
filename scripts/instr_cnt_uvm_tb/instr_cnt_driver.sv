// =============================================================================
// File        : instr_cnt_driver.sv
// Description : UVM Driver for the Instruction Counter VIP.
//               Drives bus transactions AND the instr_retire signal.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef INSTR_CNT_DRIVER_SV
`define INSTR_CNT_DRIVER_SV

class instr_cnt_driver extends uvm_driver #(instr_cnt_seq_item);

  `uvm_component_utils(instr_cnt_driver)

  // ---------------------------------------------------------------------------
  // Virtual Interface
  // ---------------------------------------------------------------------------
  virtual hpm_soc_if vif;

  // Base address of Instruction Counter
  parameter logic [31:0] INSTR_CNT_BASE = 32'h0000_2400;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "instr_cnt_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual hpm_soc_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF",
        "instr_cnt_driver: No virtual hpm_soc_if found in config_db.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    instr_cnt_seq_item req;

    // Idle outputs
    vif.cb.bus_req      <= 1'b0;
    vif.cb.bus_we       <= 1'b0;
    vif.cb.bus_addr     <= '0;
    vif.cb.bus_wdata    <= '0;
    vif.cb.bus_wstrb    <= 4'hF;
    vif.cb.instr_retire <= 1'b0;

    @(posedge vif.rst_n);
    @(vif.cb);

    forever begin
      seq_item_port.get_next_item(req);

      // Drive bus transaction first
      drive_transaction(req);

      // If retire pulses requested, drive them
      if (req.retire_count > 0) begin
        drive_retire_pulses(req.retire_count);
      end else if (req.instr_retire) begin
        drive_retire_pulse();
      end

      seq_item_port.item_done();
    end
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // drive_transaction: Drive one bus transaction to Instruction Counter
  // ---------------------------------------------------------------------------
  virtual task drive_transaction(instr_cnt_seq_item req);
    @(vif.cb);
    vif.cb.bus_req   <= 1'b1;
    vif.cb.bus_we    <= req.we;
    vif.cb.bus_addr  <= INSTR_CNT_BASE | {24'h0, req.addr};
    vif.cb.bus_wdata <= req.we ? req.data : 32'h0;
    vif.cb.bus_wstrb <= req.wstrb;

    `uvm_info("INSTR_DRV",
      $sformatf("Drive bus: addr=0x%08h we=%0b data=0x%08h",
        INSTR_CNT_BASE | {24'h0, req.addr}, req.we, req.data),
      UVM_HIGH)

    // Wait for ready
    begin : wait_ready
      int timeout = 0;
      while (!vif.cb.bus_ready) begin
        @(vif.cb);
        timeout++;
        if (timeout > 100) begin
          `uvm_error("TIMEOUT",
            "instr_cnt_driver: bus_ready timeout after 100 cycles")
          break;
        end
      end
    end

    // Sample response
    req.rdata = vif.cb.bus_rdata;
    req.ready = vif.cb.bus_ready;
    req.err   = vif.cb.bus_err;

    if (req.err) begin
      `uvm_error("BUS_ERR",
        $sformatf("Bus error on Instruction Counter addr=0x%08h",
          INSTR_CNT_BASE | {24'h0, req.addr}))
    end

    @(vif.cb);
    vif.cb.bus_req <= 1'b0;
    vif.cb.bus_we  <= 1'b0;
  endtask : drive_transaction

  // ---------------------------------------------------------------------------
  // drive_retire_pulse: Assert instr_retire for 1 clock cycle
  // ---------------------------------------------------------------------------
  virtual task drive_retire_pulse();
    @(vif.cb);
    vif.cb.instr_retire <= 1'b1;
    `uvm_info("INSTR_DRV", "instr_retire pulse driven (1 cycle)", UVM_HIGH)
    @(vif.cb);
    vif.cb.instr_retire <= 1'b0;
  endtask : drive_retire_pulse

  // ---------------------------------------------------------------------------
  // drive_retire_pulses: Drive N retire pulses, 1 cycle each, 1 cycle apart
  // ---------------------------------------------------------------------------
  virtual task drive_retire_pulses(int unsigned count);
    `uvm_info("INSTR_DRV",
      $sformatf("Driving %0d retire pulses", count), UVM_MEDIUM)
    repeat (count) begin
      @(vif.cb);
      vif.cb.instr_retire <= 1'b1;
      @(vif.cb);
      vif.cb.instr_retire <= 1'b0;
    end
    `uvm_info("INSTR_DRV",
      $sformatf("Done driving %0d retire pulses", count), UVM_MEDIUM)
  endtask : drive_retire_pulses

endclass : instr_cnt_driver

`endif // INSTR_CNT_DRIVER_SV
