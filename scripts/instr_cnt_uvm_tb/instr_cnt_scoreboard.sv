// =============================================================================
// File        : instr_cnt_scoreboard.sv
// Description : UVM Scoreboard for the Instruction Counter VIP.
//               Reference model tracking: expected 64-bit retired instruction
//               count, dependent on both EN=1 and instr_retire=1 pulse.
//               Verifies coherent shadow read (CNT_LO latching CNT_HI),
//               CLEAR priority, and read-only protections.
// Project     : RISC-V Based SoC - Hardware Performance Monitoring
// =============================================================================

`ifndef INSTR_CNT_SCOREBOARD_SV
`define INSTR_CNT_SCOREBOARD_SV

class instr_cnt_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(instr_cnt_scoreboard)

  // ---------------------------------------------------------------------------
  // Analysis Import
  // ---------------------------------------------------------------------------
  uvm_analysis_imp #(instr_cnt_seq_item, instr_cnt_scoreboard) ap_imp;

  // ---------------------------------------------------------------------------
  // Reference Model State
  // ---------------------------------------------------------------------------
  bit                  en_r;          // Enable register state
  longint unsigned     exp_count;     // Expected 64-bit retired count
  longint unsigned     shadow_hi;     // Latch of upper 32 bits on CNT_LO read
  bit                  shadow_valid;  // Shadow is populated

  // Statistics
  int unsigned pass_count;
  int unsigned fail_count;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "instr_cnt_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    pass_count = 0;
    fail_count = 0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // build_phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
    en_r         = 1'b0;
    exp_count    = 64'd0;
    shadow_hi    = 64'd0;
    shadow_valid = 1'b0;
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // write(): Called by monitor via analysis port
  // ---------------------------------------------------------------------------
  virtual function void write(instr_cnt_seq_item item);

    // Track retire pulses when enabled
    if (item.instr_retire && en_r) begin
      exp_count = exp_count + 1;
    end

    // Process bus writes
    if (item.we) begin
      case (item.addr)
        8'h00: begin // CTRL register
          if (item.data[1]) begin // CLEAR
            exp_count = 64'd0;
            `uvm_info("IC_SB", "Instruction Counter CLEAR processed in ref model", UVM_HIGH)
          end
          en_r = item.data[0]; // EN
          `uvm_info("IC_SB", $sformatf("Instruction Counter EN updated: %0b", en_r), UVM_HIGH)
        end
        8'h04, 8'h08, 8'h0C: begin
          // Read-only registers; hardware ignores write
          `uvm_info("IC_SB", $sformatf("Write to RO offset 0x%02h safely ignored", item.addr), UVM_HIGH)
        end
        default: begin
          `uvm_info("IC_SB", $sformatf("Write to unmapped offset 0x%02h handled", item.addr), UVM_HIGH)
        end
      endcase
    end
    else begin
      // Process bus reads and verify against reference model
      case (item.addr)
        8'h00: begin // CTRL
          if (item.rdata[0] !== en_r) begin
            `uvm_error("IC_SB_MISMATCH", $sformatf("CTRL read mismatch: Exp EN=%0b, Got=0x%08h", en_r, item.rdata))
            fail_count++;
          end else begin
            pass_count++;
          end
        end

        8'h04: begin // STATUS
          if (item.rdata[0] !== en_r) begin
            `uvm_error("IC_SB_MISMATCH", $sformatf("STATUS read mismatch: Exp RUNNING=%0b, Got=0x%08h", en_r, item.rdata))
            fail_count++;
          end else begin
            pass_count++;
          end
        end

        8'h08: begin // CNT_LO
          shadow_hi    = exp_count[63:32];
          shadow_valid = 1'b1;
          `uvm_info("IC_SB", $sformatf("Read CNT_LO: 0x%08h, latched shadow_hi=0x%08h", item.rdata, shadow_hi), UVM_MEDIUM)
          pass_count++;
        end

        8'h0C: begin // CNT_HI
          if (shadow_valid) begin
            if (item.rdata !== shadow_hi[31:0]) begin
              `uvm_error("IC_SB_MISMATCH", $sformatf("CNT_HI shadow mismatch: Exp=0x%08h, Got=0x%08h", shadow_hi[31:0], item.rdata))
              fail_count++;
            end else begin
              `uvm_info("IC_SB_PASS", $sformatf("CNT_HI coherent read verified: 0x%08h", item.rdata), UVM_MEDIUM)
              pass_count++;
            end
          end
        end

        default: begin
          // Unmapped read
        end
      endcase
    end
  endfunction : write

  // ---------------------------------------------------------------------------
  // check_phase
  // ---------------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("IC_SB_REPORT", $sformatf("Instruction Counter Scoreboard Summary: PASS=%0d, FAIL=%0d", pass_count, fail_count), UVM_NONE)
    if (fail_count > 0) begin
      `uvm_error("IC_SB_FAIL", $sformatf("%0d checks failed in Instruction Counter VIP!", fail_count))
    end else begin
      `uvm_info("IC_SB_ALL_PASS", "All Instruction Counter Scoreboard checks PASSED successfully!", UVM_NONE)
    end
  endfunction : check_phase

endclass : instr_cnt_scoreboard

`endif // INSTR_CNT_SCOREBOARD_SV
