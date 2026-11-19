// =============================================================================
// File        : event_cnt_seq_item.sv
// Description : UVM Sequence Item for the Event Counter VIP.
//               Covers bus transactions AND event pulse stimulus.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef EVENT_CNT_SEQ_ITEM_SV
`define EVENT_CNT_SEQ_ITEM_SV

class event_cnt_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(event_cnt_seq_item)
    `uvm_field_int(addr,      UVM_ALL_ON)
    `uvm_field_int(data,      UVM_ALL_ON)
    `uvm_field_int(we,        UVM_ALL_ON)
    `uvm_field_int(wstrb,     UVM_ALL_ON)
    `uvm_field_int(rdata,     UVM_ALL_ON)
    `uvm_field_int(event_in,  UVM_ALL_ON)
    `uvm_field_int(evt_sel,   UVM_ALL_ON)
    `uvm_field_int(irq_out,   UVM_ALL_ON)
    `uvm_field_int(err,       UVM_ALL_ON)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Bus Transaction Fields
  // ---------------------------------------------------------------------------
  rand logic [7:0]  addr;        // Offset within Event Counter address space
  rand logic [31:0] data;        // Write data
  rand logic        we;          // Write enable
       logic [3:0]  wstrb;       // Byte write strobes
       logic [31:0] rdata;       // Captured read data
       logic        err;         // Bus error

  // ---------------------------------------------------------------------------
  // Event Stimulus Fields
  // ---------------------------------------------------------------------------
  rand logic [7:0]  event_in;    // 8 event pulse inputs (1-cycle pulses)
  rand logic [2:0]  evt_sel;     // Which event index is selected (0-7)

  // ---------------------------------------------------------------------------
  // IRQ Observation
  // ---------------------------------------------------------------------------
       logic        irq_out;     // Observed IRQ output from DUT

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------
  // Valid register addresses
  constraint c_valid_addr {
    addr inside {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10};
  }

  // Writable registers: CTRL(0x00), EVT_SEL(0x04), THRESH(0x0C), STATUS(0x10 W1C)
  // COUNT(0x08) is read-only
  constraint c_write_only_rw_regs {
    if (we == 1'b1) addr inside {8'h00, 8'h04, 8'h0C, 8'h10};
  }

  // CTRL bits: [0]=EN, [1]=CLEAR, [2]=IRQ_EN (others 0)
  constraint c_ctrl_data {
    if (we == 1'b1 && addr == 8'h00) data[31:3] == 29'h0;
  }

  // EVT_SEL only lower 3 bits valid
  constraint c_evt_sel_data {
    if (we == 1'b1 && addr == 8'h04) data[31:3] == 29'h0;
  }

  // evt_sel covers all 8 events
  constraint c_evt_sel_range {
    evt_sel inside {[3'd0:3'd7]};
  }

  // event_in: only one event at a time (one-hot) or zero
  constraint c_event_one_hot {
    $onehot0(event_in);
  }

  // Full word writes
  constraint c_wstrb {
    wstrb == 4'hF;
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "event_cnt_seq_item");
    super.new(name);
    wstrb   = 4'hF;
    rdata   = '0;
    err     = 1'b0;
    irq_out = 1'b0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // convert2string
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf(
      "event_cnt_seq_item: addr=0x%02h we=%0b data=0x%08h rdata=0x%08h event_in=0b%08b evt_sel=%0d irq_out=%0b err=%0b",
      addr, we, data, rdata, event_in, evt_sel, irq_out, err
    );
  endfunction : convert2string

  // ---------------------------------------------------------------------------
  // do_copy
  // ---------------------------------------------------------------------------
  virtual function void do_copy(uvm_object rhs);
    event_cnt_seq_item rhs_item;
    super.do_copy(rhs);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_copy: rhs is not event_cnt_seq_item")
    end
    addr     = rhs_item.addr;
    data     = rhs_item.data;
    we       = rhs_item.we;
    wstrb    = rhs_item.wstrb;
    rdata    = rhs_item.rdata;
    event_in = rhs_item.event_in;
    evt_sel  = rhs_item.evt_sel;
    irq_out  = rhs_item.irq_out;
    err      = rhs_item.err;
  endfunction : do_copy

  // ---------------------------------------------------------------------------
  // do_compare
  // ---------------------------------------------------------------------------
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    event_cnt_seq_item rhs_item;
    bit result;
    result = super.do_compare(rhs, comparer);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_compare: rhs is not event_cnt_seq_item")
    end
    result &= (addr     === rhs_item.addr);
    result &= (we       === rhs_item.we);
    result &= (data     === rhs_item.data);
    result &= (rdata    === rhs_item.rdata);
    result &= (evt_sel  === rhs_item.evt_sel);
    result &= (irq_out  === rhs_item.irq_out);
    result &= (err      === rhs_item.err);
    return result;
  endfunction : do_compare

  // ---------------------------------------------------------------------------
  // do_print
  // ---------------------------------------------------------------------------
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",     addr,     8,  UVM_HEX);
    printer.print_field_int("we",       we,       1,  UVM_BIN);
    printer.print_field_int("data",     data,     32, UVM_HEX);
    printer.print_field_int("wstrb",    wstrb,    4,  UVM_BIN);
    printer.print_field_int("rdata",    rdata,    32, UVM_HEX);
    printer.print_field_int("event_in", event_in, 8,  UVM_BIN);
    printer.print_field_int("evt_sel",  evt_sel,  3,  UVM_DEC);
    printer.print_field_int("irq_out",  irq_out,  1,  UVM_BIN);
    printer.print_field_int("err",      err,      1,  UVM_BIN);
  endfunction : do_print

endclass : event_cnt_seq_item

`endif // EVENT_CNT_SEQ_ITEM_SV
