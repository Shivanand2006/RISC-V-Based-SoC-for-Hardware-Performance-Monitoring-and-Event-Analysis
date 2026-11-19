// =============================================================================
// File        : bus_decoder_scoreboard.sv
// Description : UVM Scoreboard for Central Bus Decoder VIP.
//               Validates that mapped addresses route without error (err=0),
//               and unmapped addresses return single-cycle error response (err=1).
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef BUS_DECODER_SCOREBOARD_SV
`define BUS_DECODER_SCOREBOARD_SV

class bus_decoder_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(bus_decoder_scoreboard)

  uvm_analysis_imp #(bus_decoder_seq_item, bus_decoder_scoreboard) ap_imp;

  int unsigned pass_count;
  int unsigned fail_count;

  function new(string name = "bus_decoder_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    pass_count = 0;
    fail_count = 0;
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction : build_phase

  virtual function void write(bus_decoder_seq_item item);
    bit is_mapped;

    // Check if address falls in any defined SoC module range
    if ((item.addr <= 32'h0000_0FFF) || // IMEM
        (item.addr >= 32'h0000_1000 && item.addr <= 32'h0000_1FFF) || // DMEM
        (item.addr >= 32'h0000_2000 && item.addr <= 32'h0000_20FF) || // UART
        (item.addr >= 32'h0000_2100 && item.addr <= 32'h0000_21FF) || // TIMER
        (item.addr >= 32'h0000_2200 && item.addr <= 32'h0000_22FF) || // GPIO
        (item.addr >= 32'h0000_2300 && item.addr <= 32'h0000_23FF) || // CYCLE_CNT
        (item.addr >= 32'h0000_2400 && item.addr <= 32'h0000_24FF) || // INSTR_CNT
        (item.addr >= 32'h0000_2500 && item.addr <= 32'h0000_25FF))   // EVENT_CNT
    begin
      is_mapped = 1'b1;
    end else begin
      is_mapped = 1'b0;
    end

    // Verify error response
    if (is_mapped) begin
      if (item.err !== 1'b0) begin
        `uvm_error("DEC_ERR_UNEXPECTED", $sformatf("Mapped address 0x%08h generated unexpected bus error!", item.addr))
        fail_count++;
      end else begin
        pass_count++;
      end
    end else begin
      // Unmapped access must return err=1, ready=1, rdata=0
      if (item.err !== 1'b1) begin
        `uvm_error("DEC_ERR_MISSED", $sformatf("Unmapped address 0x%08h did not assert bus error!", item.addr))
        fail_count++;
      end else if (item.rdata !== 32'h0000_0000) begin
        `uvm_error("DEC_RDATA_NONZERO", $sformatf("Unmapped read returned non-zero rdata: 0x%08h", item.rdata))
        fail_count++;
      end else begin
        `uvm_info("DEC_PASS", $sformatf("Unmapped address 0x%08h correctly terminated with err=1", item.addr), UVM_HIGH)
        pass_count++;
      end
    end
  endfunction : write

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("DEC_SB_REPORT", $sformatf("Bus Decoder Scoreboard Summary: PASS=%0d, FAIL=%0d", pass_count, fail_count), UVM_NONE)
    if (fail_count > 0) begin
      `uvm_error("DEC_SB_FAIL", $sformatf("%0d checks failed in Bus Decoder VIP!", fail_count))
    end else begin
      `uvm_info("DEC_SB_ALL_PASS", "All Bus Decoder Scoreboard checks PASSED successfully!", UVM_NONE)
    end
  endfunction : check_phase

endclass : bus_decoder_scoreboard

`endif // BUS_DECODER_SCOREBOARD_SV
