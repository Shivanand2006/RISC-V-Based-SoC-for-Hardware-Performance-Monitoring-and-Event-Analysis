// =============================================================================
// File        : event_cnt_monitor.sv
// Description : UVM Monitor for the Event Counter VIP.
//               Monitors bus transactions AND event pulses AND irq_o assertion.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef EVENT_CNT_MONITOR_SV
`define EVENT_CNT_MONITOR_SV

class event_cnt_monitor extends uvm_monitor;

  `uvm_component_utils(event_cnt_monitor)

  // ---------------------------------------------------------------------------
  // Analysis Port
  // ---------------------------------------------------------------------------
  uvm_analysis_port #(event_cnt_seq_item) ap;

  // ---------------------------------------------------------------------------
  // Virtual Interface
  // ---------------------------------------------------------------------------
  virtual hpm_soc_if vif;

  // Address range
  parameter logic [31:0] EVENT_CNT_BASE = 32'h0000_2500;
  parameter logic [31:0] EVENT_CNT_END  = 32'h0000_25FF;

  // Current EVT_SEL tracked by monitor
  logic [2:0] current_evt_sel;

  // ---------------------------------------------------------------------------
  // Functional Coverage
  // ---------------------------------------------------------------------------
  covergroup cg_event_cnt_access;
    cp_addr: coverpoint sampled_addr {
      bins CTRL    = {8'h00};
      bins EVT_SEL = {8'h04};
      bins COUNT   = {8'h08};
      bins THRESH  = {8'h0C};
      bins STATUS  = {8'h10};
    }
    cp_we: coverpoint sampled_we {
      bins READ  = {1'b0};
      bins WRITE = {1'b1};
    }
    cp_evt_sel: coverpoint sampled_evt_sel {
      bins LOAD       = {3'd0};
      bins STORE      = {3'd1};
      bins FETCH      = {3'd2};
      bins BRANCH     = {3'd3};
      bins STALL      = {3'd4};
      bins EXCEPTION  = {3'd5};
      bins TIMER_TICK = {3'd6};
      bins UART_TX    = {3'd7};
    }
    cp_irq: coverpoint sampled_irq {
      bins NO_IRQ = {1'b0};
      bins IRQ    = {1'b1};
    }
    cp_cross_sel_we: cross cp_evt_sel, cp_we;
  endgroup : cg_event_cnt_access

  logic [7:0] sampled_addr;
  logic       sampled_we;
  logic [2:0] sampled_evt_sel;
  logic       sampled_irq;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "event_cnt_monitor", uvm_component parent = null);
    super.new(name, parent);
    cg_event_cnt_access = new();
    current_evt_sel = 3'd0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual hpm_soc_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "event_cnt_monitor: No virtual hpm_soc_if in config_db.")
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // run_phase: Two parallel threads – bus monitor and event monitor
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);
    fork
      monitor_bus();
      monitor_events();
    join
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // monitor_bus: Sample bus transactions
  // ---------------------------------------------------------------------------
  virtual task monitor_bus();
    event_cnt_seq_item item;
    forever begin
      @(vif.cb);
      if (vif.cb.bus_req && vif.cb.bus_ready) begin
        if (vif.cb.bus_addr >= EVENT_CNT_BASE &&
            vif.cb.bus_addr <= EVENT_CNT_END) begin

          item = event_cnt_seq_item::type_id::create("mon_item");
          item.addr    = vif.cb.bus_addr[7:0];
          item.we      = vif.cb.bus_we;
          item.data    = vif.cb.bus_wdata;
          item.wstrb   = vif.cb.bus_wstrb;
          item.rdata   = vif.cb.bus_rdata;
          item.err     = vif.cb.bus_err;
          item.irq_out = vif.cb.irq_o;
          item.evt_sel = current_evt_sel;
          item.event_in = '0; // Bus transaction, no event pulse in this item

          // Track EVT_SEL writes
          if (item.we && item.addr == 8'h04) begin
            current_evt_sel = item.data[2:0];
            `uvm_info("MON", $sformatf("EVT_SEL updated to %0d", current_evt_sel), UVM_MEDIUM)
          end

          sampled_addr    = item.addr;
          sampled_we      = item.we;
          sampled_evt_sel = current_evt_sel;
          sampled_irq     = item.irq_out;
          cg_event_cnt_access.sample();

          `uvm_info("EVT_MON",
            $sformatf("Bus: addr=0x%02h we=%0b rdata=0x%08h irq=%0b",
              item.addr, item.we, item.rdata, item.irq_out),
            UVM_HIGH)

          ap.write(item);
        end
      end
    end
  endtask : monitor_bus

  // ---------------------------------------------------------------------------
  // monitor_events: Sample event pulse lines
  // ---------------------------------------------------------------------------
  virtual task monitor_events();
    event_cnt_seq_item item;
    logic [7:0] prev_events;
    prev_events = 8'h0;

    forever begin
      @(vif.cb);
      // Detect event pulses (rising edge detection)
      if (vif.events_in !== 8'h0) begin
        item = event_cnt_seq_item::type_id::create("evt_item");
        item.event_in = vif.events_in;
        item.evt_sel  = current_evt_sel;
        item.irq_out  = vif.cb.irq_o;
        item.we       = 1'b0; // Not a bus transaction
        item.addr     = 8'hFF; // Sentinel: event-only item
        item.rdata    = '0;
        item.err      = 1'b0;

        `uvm_info("EVT_MON",
          $sformatf("Event pulse: 0b%08b (EVT_SEL=%0d) irq=%0b",
            item.event_in, item.evt_sel, item.irq_out),
          UVM_HIGH)

        ap.write(item);
      end
    end
  endtask : monitor_events

endclass : event_cnt_monitor

`endif // EVENT_CNT_MONITOR_SV
