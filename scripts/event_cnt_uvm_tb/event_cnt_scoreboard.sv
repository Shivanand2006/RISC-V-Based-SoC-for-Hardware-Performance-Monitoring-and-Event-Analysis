// =============================================================================
// File        : event_cnt_scoreboard.sv
// Description : UVM Scoreboard for the Event Counter VIP.
//               Reference model tracking: active EVT_SEL, expected count
//               per event, threshold comparison, overflow detection,
//               W1C behaviour, and IRQ_EN gating of irq_o.
// Project     : RISC-V Based SoC – Hardware Performance Monitoring
// =============================================================================

`ifndef EVENT_CNT_SCOREBOARD_SV
`define EVENT_CNT_SCOREBOARD_SV

class event_cnt_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(event_cnt_scoreboard)

  // ---------------------------------------------------------------------------
  // Analysis Import
  // ---------------------------------------------------------------------------
  uvm_analysis_imp #(event_cnt_seq_item, event_cnt_scoreboard) ap_imp;

  // ---------------------------------------------------------------------------
  // Reference Model State
  // ---------------------------------------------------------------------------
  bit          en_r;              // EN bit
  bit          irq_en_r;         // IRQ_EN bit
  logic [2:0]  evt_sel_r;        // Currently selected event index
  int unsigned exp_count;        // Expected 32-bit event count
  int unsigned exp_thresh;       // Expected threshold value
  bit          exp_ovf;          // Expected overflow flag
  bit          exp_thresh_hit;   // Expected threshold hit flag
  bit          exp_irq;          // Expected IRQ state

  // Per-event pulse accumulation (for reference)
  int unsigned event_pulse_cnt [8];

  // Statistics
  int unsigned pass_count;
  int unsigned fail_count;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "event_cnt_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
    reset_model();
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // reset_model: Reset all reference model state
  // ---------------------------------------------------------------------------
  virtual function void reset_model();
    en_r           = 1'b0;
    irq_en_r       = 1'b0;
    evt_sel_r      = 3'd0;
    exp_count      = 0;
    exp_thresh     = 0;
    exp_ovf        = 1'b0;
    exp_thresh_hit = 1'b0;
    exp_irq        = 1'b0;
    pass_count     = 0;
    fail_count     = 0;
    foreach (event_pulse_cnt[i]) event_pulse_cnt[i] = 0;
  endfunction : reset_model

  // ---------------------------------------------------------------------------
  // write: Called by analysis port for every captured transaction
  // ---------------------------------------------------------------------------
  virtual function void write(event_cnt_seq_item item);

    // ---- Event pulse received (sentinel addr = 0xFF) ----
    if (item.addr == 8'hFF && !item.we) begin
      handle_event_pulse(item);
      return;
    end

    // ---- Bus WRITE transaction ----
    if (item.we) begin
      handle_write(item);
    end
    // ---- Bus READ transaction ----
    else begin
      handle_read(item);
    end
  endfunction : write

  // ---------------------------------------------------------------------------
  // handle_event_pulse
  // ---------------------------------------------------------------------------
  virtual function void handle_event_pulse(event_cnt_seq_item item);
    if (!en_r) begin
      `uvm_info("SB_EVT", "Event pulse received but EN=0 – ignoring", UVM_HIGH)
      return;
    end

    // Count pulse for selected event
    if (item.event_in[evt_sel_r]) begin
      event_pulse_cnt[evt_sel_r]++;

      // Check for overflow before increment
      if (exp_count == 32'hFFFF_FFFF) begin
        exp_count = 0;
        exp_ovf   = 1'b1;
        `uvm_info("SB_OVF", "Reference model: 32-bit overflow occurred", UVM_MEDIUM)
      end else begin
        exp_count++;
      end

      // Check threshold
      if (exp_count >= exp_thresh && exp_thresh > 0) begin
        exp_thresh_hit = 1'b1;
      end

      // Update expected IRQ
      exp_irq = irq_en_r && (exp_ovf || exp_thresh_hit);

      `uvm_info("SB_EVT",
        $sformatf("Event[%0d] pulse. exp_count=%0d thresh=%0d thresh_hit=%0b ovf=%0b irq=%0b",
          evt_sel_r, exp_count, exp_thresh, exp_thresh_hit, exp_ovf, exp_irq),
        UVM_HIGH)
    end
  endfunction : handle_event_pulse

  // ---------------------------------------------------------------------------
  // handle_write
  // ---------------------------------------------------------------------------
  virtual function void handle_write(event_cnt_seq_item item);
    case (item.addr)
      8'h00: begin // CTRL
        en_r     = item.data[0];
        irq_en_r = item.data[2];
        if (item.data[1]) begin // CLEAR
          exp_count      = 0;
          exp_ovf        = 1'b0;
          exp_thresh_hit = 1'b0;
          exp_irq        = 1'b0;
          foreach (event_pulse_cnt[i]) event_pulse_cnt[i] = 0;
          `uvm_info("SB_WR", "Event Counter CLEARED by CTRL[1]", UVM_MEDIUM)
        end
        `uvm_info("SB_WR",
          $sformatf("CTRL write: EN=%0b IRQ_EN=%0b CLEAR=%0b",
            en_r, irq_en_r, item.data[1]),
          UVM_MEDIUM)
      end
      8'h04: begin // EVT_SEL
        evt_sel_r = item.data[2:0];
        // Reset count tracking for new selection
        exp_count = 0;
        `uvm_info("SB_WR",
          $sformatf("EVT_SEL written: selecting event %0d", evt_sel_r), UVM_MEDIUM)
      end
      8'h0C: begin // THRESH
        exp_thresh = item.data;
        `uvm_info("SB_WR",
          $sformatf("THRESH written: 0x%08h (%0d)", item.data, item.data), UVM_MEDIUM)
      end
      8'h10: begin // STATUS – W1C
        // W1C: writing 1 clears the bit
        if (item.data[0]) begin // Clear OVF
          exp_ovf = 1'b0;
          `uvm_info("SB_WR", "W1C: OVF cleared", UVM_MEDIUM)
        end
        if (item.data[1]) begin // Clear THRESH_HIT
          exp_thresh_hit = 1'b0;
          `uvm_info("SB_WR", "W1C: THRESH_HIT cleared", UVM_MEDIUM)
        end
        exp_irq = irq_en_r && (exp_ovf || exp_thresh_hit);
      end
      default: begin
        `uvm_info("SB_WR",
          $sformatf("Write to unknown addr=0x%02h data=0x%08h", item.addr, item.data),
          UVM_LOW)
      end
    endcase
  endfunction : handle_write

  // ---------------------------------------------------------------------------
  // handle_read
  // ---------------------------------------------------------------------------
  virtual function void handle_read(event_cnt_seq_item item);
    case (item.addr)
      8'h08: begin // COUNT register
        check_count(item.rdata);
      end
      8'h10: begin // STATUS register
        check_status(item.rdata, item.irq_out);
      end
      default: begin
        `uvm_info("SB_RD",
          $sformatf("Read addr=0x%02h rdata=0x%08h (not checked)",
            item.addr, item.rdata),
          UVM_LOW)
      end
    endcase
  endfunction : handle_read

  // ---------------------------------------------------------------------------
  // check_count
  // ---------------------------------------------------------------------------
  virtual function void check_count(logic [31:0] got_count);
    if (got_count !== exp_count) begin
      `uvm_error("SB_COUNT",
        $sformatf("COUNT mismatch: exp=%0d (0x%08h) got=%0d (0x%08h)",
          exp_count, exp_count, got_count, got_count))
      fail_count++;
    end else begin
      `uvm_info("SB_COUNT",
        $sformatf("COUNT OK: %0d (0x%08h)", got_count, got_count), UVM_MEDIUM)
      pass_count++;
    end
  endfunction : check_count

  // ---------------------------------------------------------------------------
  // check_status
  // ---------------------------------------------------------------------------
  virtual function void check_status(logic [31:0] got_status, logic got_irq);
    bit got_ovf        = got_status[0];
    bit got_thresh_hit = got_status[1];
    bit got_running    = got_status[2];
    bit ok = 1;

    if (got_ovf !== exp_ovf) begin
      `uvm_error("SB_OVF",
        $sformatf("STATUS[OVF] mismatch: exp=%0b got=%0b", exp_ovf, got_ovf))
      ok = 0; fail_count++;
    end

    if (got_thresh_hit !== exp_thresh_hit) begin
      `uvm_error("SB_THRESH",
        $sformatf("STATUS[THRESH_HIT] mismatch: exp=%0b got=%0b",
          exp_thresh_hit, got_thresh_hit))
      ok = 0; fail_count++;
    end

    if (got_running !== en_r) begin
      `uvm_error("SB_RUN",
        $sformatf("STATUS[RUNNING] mismatch: exp=%0b got=%0b", en_r, got_running))
      ok = 0; fail_count++;
    end

    // IRQ check
    if (got_irq !== exp_irq) begin
      `uvm_error("SB_IRQ",
        $sformatf("IRQ mismatch: exp=%0b got=%0b (IRQ_EN=%0b OVF=%0b THRESH_HIT=%0b)",
          exp_irq, got_irq, irq_en_r, exp_ovf, exp_thresh_hit))
      ok = 0; fail_count++;
    end

    if (ok) begin
      `uvm_info("SB_STATUS",
        $sformatf("STATUS OK: OVF=%0b THRESH_HIT=%0b RUNNING=%0b IRQ=%0b",
          got_ovf, got_thresh_hit, got_running, got_irq),
        UVM_MEDIUM)
      pass_count++;
    end
  endfunction : check_status

  // ---------------------------------------------------------------------------
  // check_phase
  // ---------------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    `uvm_info("SB_SUMMARY",
      $sformatf("=== Event Counter Scoreboard Summary ===\n  PASS: %0d\n  FAIL: %0d",
        pass_count, fail_count),
      UVM_NONE)
    if (fail_count > 0) begin
      `uvm_error("SB_FAIL",
        $sformatf("event_cnt_scoreboard: %0d check(s) FAILED", fail_count))
    end else begin
      `uvm_info("SB_PASS", "event_cnt_scoreboard: ALL CHECKS PASSED", UVM_NONE)
    end
  endfunction : check_phase

endclass : event_cnt_scoreboard

`endif // EVENT_CNT_SCOREBOARD_SV
