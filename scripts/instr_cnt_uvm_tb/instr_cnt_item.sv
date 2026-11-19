// =============================================================================
// File        : instr_cnt_seq_item.sv
// Description : UVM Sequence Item for the Instruction Counter VIP.
//               Same register layout as Cycle Counter but adds instr_retire.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef INSTR_CNT_SEQ_ITEM_SV
`define INSTR_CNT_SEQ_ITEM_SV

class instr_cnt_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(instr_cnt_seq_item)
    `uvm_field_int(addr,         UVM_ALL_ON)
    `uvm_field_int(data,         UVM_ALL_ON)
    `uvm_field_int(we,           UVM_ALL_ON)
    `uvm_field_int(wstrb,        UVM_ALL_ON)
    `uvm_field_int(rdata,        UVM_ALL_ON)
    `uvm_field_int(ready,        UVM_ALL_ON)
    `uvm_field_int(err,          UVM_ALL_ON)
    `uvm_field_int(instr_retire, UVM_ALL_ON)
    `uvm_field_int(retire_count, UVM_ALL_ON)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Bus Transaction Fields
  // ---------------------------------------------------------------------------
  rand logic [7:0]  addr;          // Offset: CTRL=0x00, STATUS=0x04, CNT_LO=0x08, CNT_HI=0x0C
  rand logic [31:0] data;          // Write data
  rand logic        we;            // Write enable
       logic [3:0]  wstrb;         // Byte strobes
       logic [31:0] rdata;         // Captured read data
       logic        ready;         // Bus ready
       logic        err;           // Bus error

  // ---------------------------------------------------------------------------
  // Instruction Retire Fields
  // ---------------------------------------------------------------------------
  rand logic        instr_retire;  // Single retire pulse to drive in this transaction
  rand int unsigned retire_count;  // Number of retire pulses for a sequence to drive

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------
  constraint c_valid_addr {
    addr inside {8'h00, 8'h04, 8'h08, 8'h0C};
  }

  // Only CTRL is writable
  constraint c_write_only_ctrl {
    if (we == 1'b1) addr == 8'h00;
  }

  // CTRL bits: [0]=EN, [1]=CLEAR
  constraint c_ctrl_data {
    if (we == 1'b1) data[31:2] == 30'h0;
  }

  constraint c_wstrb {
    wstrb == 4'hF;
  }

  // Retire count range: 0–1000 pulses
  constraint c_retire_count {
    retire_count inside {[0:1000]};
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "instr_cnt_seq_item");
    super.new(name);
    wstrb        = 4'hF;
    rdata        = '0;
    ready        = 1'b0;
    err          = 1'b0;
    instr_retire = 1'b0;
    retire_count = 0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // convert2string
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf(
      "instr_cnt_seq_item: addr=0x%02h we=%0b data=0x%08h rdata=0x%08h retire=%0b retire_count=%0d err=%0b",
      addr, we, data, rdata, instr_retire, retire_count, err
    );
  endfunction : convert2string

  // ---------------------------------------------------------------------------
  // do_copy
  // ---------------------------------------------------------------------------
  virtual function void do_copy(uvm_object rhs);
    instr_cnt_seq_item rhs_item;
    super.do_copy(rhs);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_copy: rhs is not instr_cnt_seq_item")
    end
    addr         = rhs_item.addr;
    data         = rhs_item.data;
    we           = rhs_item.we;
    wstrb        = rhs_item.wstrb;
    rdata        = rhs_item.rdata;
    ready        = rhs_item.ready;
    err          = rhs_item.err;
    instr_retire = rhs_item.instr_retire;
    retire_count = rhs_item.retire_count;
  endfunction : do_copy

  // ---------------------------------------------------------------------------
  // do_compare
  // ---------------------------------------------------------------------------
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    instr_cnt_seq_item rhs_item;
    bit result;
    result = super.do_compare(rhs, comparer);
    if (!$cast(rhs_item, rhs)) begin
      `uvm_fatal("TYPE_MISMATCH", "do_compare: rhs is not instr_cnt_seq_item")
    end
    result &= (addr         === rhs_item.addr);
    result &= (we           === rhs_item.we);
    result &= (data         === rhs_item.data);
    result &= (rdata        === rhs_item.rdata);
    result &= (instr_retire === rhs_item.instr_retire);
    result &= (err          === rhs_item.err);
    return result;
  endfunction : do_compare

  // ---------------------------------------------------------------------------
  // do_print
  // ---------------------------------------------------------------------------
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",         addr,         8,  UVM_HEX);
    printer.print_field_int("we",           we,           1,  UVM_BIN);
    printer.print_field_int("data",         data,         32, UVM_HEX);
    printer.print_field_int("wstrb",        wstrb,        4,  UVM_BIN);
    printer.print_field_int("rdata",        rdata,        32, UVM_HEX);
    printer.print_field_int("ready",        ready,        1,  UVM_BIN);
    printer.print_field_int("err",          err,          1,  UVM_BIN);
    printer.print_field_int("instr_retire", instr_retire, 1,  UVM_BIN);
    printer.print_field_int("retire_count", retire_count, 32, UVM_DEC);
  endfunction : do_print

endclass : instr_cnt_seq_item

`endif // INSTR_CNT_SEQ_ITEM_SV
