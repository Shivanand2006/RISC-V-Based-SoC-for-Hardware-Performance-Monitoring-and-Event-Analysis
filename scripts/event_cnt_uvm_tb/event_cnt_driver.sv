// =============================================================================
// File        : event_cnt_driver.sv
// Description : UVM Driver for the Event Counter VIP.
//               Drives bus transactions AND event_in[7:0] pulse lines.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef EVENT_CNT_DRIVER_SV
`define EVENT_CNT_DRIVER_SV

class event_cnt_driver extends uvm_driver #(event_cnt_seq_item);

  `uvm_component_utils(event_cnt_driver)

  // ---------------------------------------------------------------------------
  // Virtual Interface Handle
  // ---------------------------------------------------------------------------
  virtual hpm_soc_if vif;

  // Base address of Event Counter
  parameter logic [31:0] EVENT_CNT_BASE = 32'h0000_2500;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "event_cnt_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual hpm_soc_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF",
        "event_cnt_driver: No virtual hpm_soc_if found in config_db.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    event_cnt_seq_item req;

    // Idle all outputs
    idle_bus();
    idle_events();

    @(posedge vif.rst_n);
    @(vif.cb);

    forever begin
      seq_item_port.get_next_item(req);
      if (req.we || !req.we) begin
        // Drive bus transaction if address is set
        drive_transaction(req);
      end
      if (|req.event_in) begin
        // Drive event pulse(s)
        drive_event_pulse(req.event_in);
      end
      seq_item_port.item_done();
    end
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // idle_bus: Deassert all bus signals
  // ---------------------------------------------------------------------------
  virtual task idle_bus();
    vif.cb.bus_req   <= 1'b0;
    vif.cb.bus_we    <= 1'b0;
    vif.cb.bus_addr  <= '0;
    vif.cb.bus_wdata <= '0;
    vif.cb.bus_wstrb <= 4'hF;
  endtask : idle_bus

  // ---------------------------------------------------------------------------
  // idle_events: Deassert all event inputs
  // ---------------------------------------------------------------------------
  virtual task idle_events();
    vif.cb.load_event         <= 1'b0;
    vif.cb.store_event        <= 1'b0;
    vif.cb.fetch_event        <= 1'b0;
    vif.cb.branch_jump_event  <= 1'b0;
    vif.cb.stall_event        <= 1'b0;
    vif.cb.exception_event    <= 1'b0;
    vif.cb.timer_tick_event   <= 1'b0;
    vif.cb.uart_tx_done_event <= 1'b0;
  endtask : idle_events

  // ---------------------------------------------------------------------------
  // drive_transaction: Drive one bus transaction to Event Counter
  // ---------------------------------------------------------------------------
  virtual task drive_transaction(event_cnt_seq_item req);
    @(vif.cb);
    vif.cb.bus_req   <= 1'b1;
    vif.cb.bus_we    <= req.we;
    vif.cb.bus_addr  <= EVENT_CNT_BASE | {24'h0, req.addr};
    vif.cb.bus_wdata <= req.we ? req.data : 32'h0;
    vif.cb.bus_wstrb <= req.wstrb;

    `uvm_info("EVT_DRV",
      $sformatf("Drive bus: addr=0x%08h we=%0b data=0x%08h",
        EVENT_CNT_BASE | {24'h0, req.addr}, req.we, req.data),
      UVM_HIGH)

    // Wait for ready
    begin : wait_ready
      int timeout = 0;
      while (!vif.cb.bus_ready) begin
        @(vif.cb);
        timeout++;
        if (timeout > 100) begin
          `uvm_error("TIMEOUT", "event_cnt_driver: bus_ready timeout after 100 cycles")
          break;
        end
      end
    end

    // Sample response
    req.rdata   = vif.cb.bus_rdata;
    req.err     = vif.cb.bus_err;
    req.irq_out = vif.cb.irq_o;

    if (req.err) begin
      `uvm_error("BUS_ERR",
        $sformatf("Bus error on Event Counter addr=0x%08h",
          EVENT_CNT_BASE | {24'h0, req.addr}))
    end

    @(vif.cb);
    vif.cb.bus_req <= 1'b0;
    vif.cb.bus_we  <= 1'b0;
  endtask : drive_transaction

  // ---------------------------------------------------------------------------
  // drive_event_pulse: Assert event_in[7:0] for 1 clock cycle
  // ---------------------------------------------------------------------------
  virtual task drive_event_pulse(logic [7:0] event_mask);
    @(vif.cb);
    // Assign individual event signals based on mask bits
    vif.cb.load_event         <= event_mask[0];
    vif.cb.store_event        <= event_mask[1];
    vif.cb.fetch_event        <= event_mask[2];
    vif.cb.branch_jump_event  <= event_mask[3];
    vif.cb.stall_event        <= event_mask[4];
    vif.cb.exception_event    <= event_mask[5];
    vif.cb.timer_tick_event   <= event_mask[6];
    vif.cb.uart_tx_done_event <= event_mask[7];

    `uvm_info("EVT_DRV",
      $sformatf("Event pulse driven: 0b%08b", event_mask), UVM_HIGH)

    // Hold for 1 cycle then deassert
    @(vif.cb);
    idle_events();
  endtask : drive_event_pulse

endclass : event_cnt_driver

`endif // EVENT_CNT_DRIVER_SV
