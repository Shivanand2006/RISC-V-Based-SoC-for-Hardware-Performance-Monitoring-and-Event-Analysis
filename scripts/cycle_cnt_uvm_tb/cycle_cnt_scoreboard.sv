// =============================================================================
// File        : cycle_cnt_scoreboard.sv
// Description : UVM Scoreboard for the Cycle Counter VIP.
//               Reference model tracks expected 64-bit count based on EN,
//               CLEAR, and elapsed clock cycles. Verifies CNT_LO/HI reads,
//               shadow latch behaviour, and STATUS accuracy.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef CYCLE_CNT_SCOREBOARD_SV
`define CYCLE_CNT_SCOREBOARD_SV

class cycle_cnt_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(cycle_cnt_scoreboard)

  // ---------------------------------------------------------------------------
  // Analysis Imports (write transactions and read transactions)
  // ---------------------------------------------------------------------------
  uvm_analysis_imp_wr #(cycle_cnt_seq_item, cycle_cnt_scoreboard) wr_imp;
  uvm_analysis_imp_rd #(cycle_cnt_seq_item, cycle_cnt_scoreboard) rd_imp;

  // ---------------------------------------------------------------------------
  // Reference Model State
  // ---------------------------------------------------------------------------
  bit          en_r;              // Current EN bit state
  bit          clear_pending;     // CLEAR was written
  longint unsigned exp_count;     // Expected 64-bit count
  longint unsigned shadow_hi;     // Shadow CNT_HI captured on CNT_LO read
  bit          shadow_valid;      // Shadow register is valid

  // Statistics
  int unsigned pass_count;
  int unsigned fail_count;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "cycle_cnt_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wr_imp = new("wr_imp", this);
    rd_imp = new("rd_imp", this);
    en_r          = 1'b0;
    clear_pending = 1'b0;
    exp_count     = 64'h0;
    shadow_hi     = 64'h0;
    shadow_valid  = 1'b0;
    pass_count    = 0;
    fail_count    = 0;
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // write_wr: Called by monitor analysis port for WRITE transactions
  // ---------------------------------------------------------------------------
  virtual function void write_wr(cycle_cnt_seq_item item);
    if (item.we && item.addr == 8'h00) begin
      // CTRL register write
      bit new_en    = item.data[0];
      bit new_clear = item.data[1];

      `uvm_info("SB_WR",
        $sformatf("CTRL write: EN=%0b CLEAR=%0b", new_en, new_clear),
        UVM_MEDIUM)

      if (new_clear) begin
        exp_count     = 64'h0;
        shadow_hi     = 64'h0;
        shadow_valid  = 1'b0;
        clear_pending = 1'b1;
        `uvm_info("SB_WR", "Reference model: Counter CLEARED", UVM_MEDIUM)
      end

      en_r = new_en;
      `uvm_info("SB_WR",
        $sformatf("Reference model: EN set to %0b", en_r), UVM_MEDIUM)
    end
  endfunction : write_wr

  // ---------------------------------------------------------------------------
  // write_rd: Called by monitor analysis port for READ transactions
  // ---------------------------------------------------------------------------
  virtual function void write_rd(cycle_cnt_seq_item item);
    if (!item.we) begin
      case (item.addr)

        8'h04: begin // STATUS register
          bit exp_running = en_r;
          bit got_running = item.rdata[0];
          if (got_running !== exp_running) begin
            `uvm_error("SB_STATUS",
              $sformatf("STATUS mismatch: exp RUNNING=%0b, got RUNNING=%0b",
                exp_running, got_running))
            fail_count++;
          end else begin
            `uvm_info("SB_STATUS",
              $sformatf("STATUS OK: RUNNING=%0b", got_running), UVM_MEDIUM)
            pass_count++;
          end
        end

        8'h08: begin // CNT_LO – also triggers shadow latch
          logic [31:0] exp_lo;
          exp_lo = exp_count[31:0];
          // Capture shadow
          shadow_hi    = exp_count[63:32];
          shadow_valid = 1'b1;

          `uvm_info("SB_CNT_LO",
            $sformatf("CNT_LO read: exp=0x%08h got=0x%08h (shadow CNT_HI latched=0x%08h)",
              exp_lo, item.rdata, shadow_hi),
            UVM_MEDIUM)

          // Allow small delta for pipelining (up to 3 cycles tolerance)
          if ((item.rdata < exp_lo - 3) || (item.rdata > exp_lo + 3)) begin
            `uvm_error("SB_CNT_LO",
              $sformatf("CNT_LO out of expected range [0x%08h ± 3]: got 0x%08h",
                exp_lo, item.rdata))
            fail_count++;
          end else begin
            `uvm_info("SB_CNT_LO", "CNT_LO value within expected range", UVM_MEDIUM)
            pass_count++;
          end
        end

        8'h0C: begin // CNT_HI – should read shadow register
          if (!shadow_valid) begin
            `uvm_error("SB_CNT_HI",
              "CNT_HI read without prior CNT_LO read – shadow invalid!")
            fail_count++;
          end else begin
            logic [31:0] exp_hi = shadow_hi[31:0];
            if (item.rdata !== exp_hi) begin
              `uvm_error("SB_CNT_HI",
                $sformatf("CNT_HI shadow mismatch: exp=0x%08h got=0x%08h",
                  exp_hi, item.rdata))
              fail_count++;
            end else begin
              `uvm_info("SB_CNT_HI",
                $sformatf("CNT_HI shadow OK: 0x%08h", item.rdata), UVM_MEDIUM)
              pass_count++;
            end
            shadow_valid = 1'b0; // Shadow consumed
          end
        end

        default: begin
          `uvm_info("SB_RD",
            $sformatf("Read from addr=0x%02h rdata=0x%08h (not checked)",
              item.addr, item.rdata),
            UVM_LOW)
        end
      endcase
    end
  endfunction : write_rd

  // ---------------------------------------------------------------------------
  // tick: Called each cycle to update expected count (from tb_top)
  // ---------------------------------------------------------------------------
  virtual function void tick();
    if (en_r && !clear_pending) begin
      exp_count++;
    end
    if (clear_pending) begin
      clear_pending = 1'b0;
    end
  endfunction : tick

  // ---------------------------------------------------------------------------
  // check_phase: Final pass/fail summary
  // ---------------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    `uvm_info("SB_SUMMARY",
      $sformatf("=== Cycle Counter Scoreboard Summary ===\n  PASS: %0d\n  FAIL: %0d",
        pass_count, fail_count),
      UVM_NONE)
    if (fail_count > 0) begin
      `uvm_error("SB_FAIL",
        $sformatf("cycle_cnt_scoreboard: %0d check(s) FAILED", fail_count))
    end else begin
      `uvm_info("SB_PASS", "cycle_cnt_scoreboard: ALL CHECKS PASSED", UVM_NONE)
    end
  endfunction : check_phase

endclass : cycle_cnt_scoreboard

`endif // CYCLE_CNT_SCOREBOARD_SV
