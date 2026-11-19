// =============================================================================
// File        : cycle_cnt_seq_item.sv
// Description : UVM Sequence Item for the Cycle Counter VIP.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef CYCLE_CNT_SEQ_ITEM_SV
`define CYCLE_CNT_SEQ_ITEM_SV

class cycle_cnt_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(cycle_cnt_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_int(we,     UVM_ALL_ON)
    `uvm_field_int(wstrb,  UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(ready,  UVM_ALL_ON)
    `uvm_field_int(err,    UVM_ALL_ON)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Transaction Fields
  // ---------------------------------------------------------------------------
  rand logic [7:0]  addr;    // Offset within Cycle Counter address space
  rand logic [31:0] data;    // Write data
  rand logic        we;      // Write enable: 1=write, 0=read
       logic [3:0]  wstrb;   // Byte write strobes (full-word by default)
       logic [31:0] rdata;   // Captured read data (output)
       logic        ready;   // Bus ready (output)
       logic        err;     // Bus error (output)

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------
  // Only valid register offsets
  constraint c_valid_addr {
    addr inside {8'h00, 8'h04, 8'h08, 8'h0C};
  }

  // Only CTRL (0x00) is writable; STATUS, CNT_LO, CNT_HI are read-only
  constraint c_write_only_ctrl {
    if (we == 1'b1) addr == 8'h00;
  }

  // Only bits [1:0] of CTRL are meaningful (EN=bit0, CLEAR=bit1)
  constraint c_ctrl_data {
    if (we == 1'b1) data[31:2] == 30'h0;
  }

  // Write strobes: full word when writing CTRL
  constraint c_wstrb {
    wstrb == 4'hF;
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "cycle_cnt_seq_item");
    super.new(name);
    wstrb = 4'hF;
    rdata = '0;
    ready = 1'b0;
    err   = 1'b0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // convert2string
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf(
      "cycle_cnt_seq_item: addr=0x%02h we=%0b data=0x%08h rdata=0x%08h ready=%0b err=%0b",
      addr, we, data, rdata, ready, err
    );
  endfunction : convert2string

  // ---------------------------------------------------------------------------
  // do_copy
  // ---------------------------------------------------------------------------
  virtual function void do_copy(uvm_object rhs);
    cycle_cnt_seq_item rhs_item;
    super.do_copy(rhs);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_copy: rhs is not cycle_cnt_seq_item")
    end
    addr  = rhs_item.addr;
    data  = rhs_item.data;
    we    = rhs_item.we;
    wstrb = rhs_item.wstrb;
    rdata = rhs_item.rdata;
    ready = rhs_item.ready;
    err   = rhs_item.err;
  endfunction : do_copy

  // ---------------------------------------------------------------------------
  // do_compare
  // ---------------------------------------------------------------------------
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    cycle_cnt_seq_item rhs_item;
    bit result;
    result = super.do_compare(rhs, comparer);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_compare: rhs is not cycle_cnt_seq_item")
    end
    result &= (addr  === rhs_item.addr);
    result &= (we    === rhs_item.we);
    result &= (data  === rhs_item.data);
    result &= (rdata === rhs_item.rdata);
    result &= (err   === rhs_item.err);
    return result;
  endfunction : do_compare

  // ---------------------------------------------------------------------------
  // do_print
  // ---------------------------------------------------------------------------
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",  addr,  8,  UVM_HEX);
    printer.print_field_int("we",    we,    1,  UVM_BIN);
    printer.print_field_int("data",  data,  32, UVM_HEX);
    printer.print_field_int("wstrb", wstrb, 4,  UVM_BIN);
    printer.print_field_int("rdata", rdata, 32, UVM_HEX);
    printer.print_field_int("ready", ready, 1,  UVM_BIN);
    printer.print_field_int("err",   err,   1,  UVM_BIN);
  endfunction : do_print

endclass : cycle_cnt_seq_item

`endif // CYCLE_CNT_SEQ_ITEM_SV
