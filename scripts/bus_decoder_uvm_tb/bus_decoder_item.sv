// =============================================================================
// File        : bus_decoder_seq_item.sv
// Description : UVM Sequence Item for Central Bus Decoder / Interconnect VIP.
//               Generates transactions targeting IMEM, DMEM, peripherals,
//               HPM counters, and unmapped address regions.
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_DECODER_SEQ_ITEM_SV
`define BUS_DECODER_SEQ_ITEM_SV

typedef enum logic [3:0] {
  TARGET_IMEM       = 4'd0,
  TARGET_DMEM       = 4'd1,
  TARGET_UART       = 4'd2,
  TARGET_TIMER      = 4'd3,
  TARGET_GPIO       = 4'd4,
  TARGET_CYCLE_CNT  = 4'd5,
  TARGET_INSTR_CNT  = 4'd6,
  TARGET_EVENT_CNT  = 4'd7,
  TARGET_UNMAPPED   = 4'd8
} target_dev_e;

class bus_decoder_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(bus_decoder_seq_item)
    `uvm_field_int(addr,          UVM_ALL_ON)
    `uvm_field_int(data,          UVM_ALL_ON)
    `uvm_field_int(we,            UVM_ALL_ON)
    `uvm_field_int(wstrb,         UVM_ALL_ON)
    `uvm_field_int(rdata,         UVM_ALL_ON)
    `uvm_field_int(ready,         UVM_ALL_ON)
    `uvm_field_int(err,           UVM_ALL_ON)
    `uvm_field_enum(target_dev_e, expected_dev, UVM_ALL_ON)
  `uvm_object_utils_end

  // Transaction Fields
  rand logic [31:0] addr;
  rand logic [31:0] data;
  rand logic        we;
  rand logic [3:0]  wstrb;
       logic [31:0] rdata;
       logic        ready;
       logic        err;

  // Expected Target Decoding
  rand target_dev_e expected_dev;

  // Constraints to distribute accesses across address spaces
  constraint c_target_dev_dist {
    expected_dev dist {
      TARGET_IMEM      := 10,
      TARGET_DMEM      := 15,
      TARGET_UART      := 10,
      TARGET_TIMER     := 10,
      TARGET_GPIO      := 10,
      TARGET_CYCLE_CNT := 15,
      TARGET_INSTR_CNT := 15,
      TARGET_EVENT_CNT := 15,
      TARGET_UNMAPPED  := 10
    };
  }

  // Address matching target device
  constraint c_addr_mapping {
    (expected_dev == TARGET_IMEM)      -> (addr inside {[32'h0000_0000 : 32'h0000_0FFF]});
    (expected_dev == TARGET_DMEM)      -> (addr inside {[32'h0000_1000 : 32'h0000_1FFF]});
    (expected_dev == TARGET_UART)      -> (addr inside {[32'h0000_2000 : 32'h0000_20FF]});
    (expected_dev == TARGET_TIMER)     -> (addr inside {[32'h0000_2100 : 32'h0000_21FF]});
    (expected_dev == TARGET_GPIO)      -> (addr inside {[32'h0000_2200 : 32'h0000_22FF]});
    (expected_dev == TARGET_CYCLE_CNT) -> (addr inside {[32'h0000_2300 : 32'h0000_23FF]});
    (expected_dev == TARGET_INSTR_CNT) -> (addr inside {[32'h0000_2400 : 32'h0000_24FF]});
    (expected_dev == TARGET_EVENT_CNT) -> (addr inside {[32'h0000_2500 : 32'h0000_25FF]});
    (expected_dev == TARGET_UNMAPPED)  -> (addr inside {[32'h0000_3000 : 32'h0000_FFFF], [32'h0001_0000 : 32'hFFFF_FFFF]});
  }

  // Word alignment constraint
  constraint c_word_aligned {
    addr[1:0] == 2'b00;
    wstrb inside {4'b1111, 4'b0001, 4'b0011};
  }

  function new(string name = "bus_decoder_seq_item");
    super.new(name);
  endfunction : new

  virtual function string convert2string();
    return $sformatf("BUS_DEC_TX: Addr=0x%08h WE=%0b Data=0x%08h RData=0x%08h Ready=%0b Err=%0b Target=%s",
                     addr, we, data, rdata, ready, err, expected_dev.name());
  endfunction : convert2string

endclass : bus_decoder_seq_item

`endif // BUS_DECODER_SEQ_ITEM_SV
