//=============================================================================
// File: riscv_core.v
// Description: Synthesizable RV32I Processor Core with direct event observation
//              outputs for hardware performance monitoring.
//              Generates retirement pulse, loads, stores, fetches, branches,
//              stalls, exceptions, and responds to timer/external interrupts.
// Standard: Synthesizable Verilog-2001
//=============================================================================

`include "riscv_defines.vh"

module riscv_core #(
    parameter RESET_VEC = 32'h0000_0000
)(
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Fetch Interface (IMEM)
    output reg         imem_req_o,
    output wire [31:0] imem_addr_o,
    input  wire        imem_ready_i,
    input  wire [31:0] imem_rdata_i,

    // Data Memory / System Bus Interface (DMEM / Interconnect)
    output reg         dmem_req_o,
    output reg         dmem_we_o,
    output reg  [31:0] dmem_addr_o,
    output reg  [31:0] dmem_wdata_o,
    output reg  [3:0]  dmem_wstrb_o,
    input  wire        dmem_ready_i,
    input  wire [31:0] dmem_rdata_i,
    input  wire        dmem_err_i,

    // Hardware Performance Monitoring and Event Signals
    output reg         instr_retire_o,     // 1-cycle pulse when instruction commits
    output reg         evt_load_o,         // 1-cycle pulse on data read request
    output reg         evt_store_o,        // 1-cycle pulse on data write request
    output reg         evt_fetch_o,        // 1-cycle pulse on instruction fetch request
    output reg         evt_branch_jump_o,  // 1-cycle pulse on branch taken or jump
    output reg         evt_stall_bubble_o, // 1-cycle pulse on stall or memory wait cycle
    output reg         evt_exception_o,    // 1-cycle pulse on trap/exception taken

    // Interrupt Inputs
    input  wire        timer_irq_i,        // Timer interrupt
    input  wire        ext_irq_i,          // External interrupt (from Event Counter)
    input  wire        uart_irq_i          // UART interrupt
);

    // States
    localparam STATE_FETCH     = 2'd0;
    localparam STATE_DECODE_EX = 2'd1;
    localparam STATE_MEM_WAIT  = 2'd2;
    localparam STATE_TRAP      = 2'd3;

    reg [1:0] state_q;

    // Registers
    reg [31:0] pc_q;
    reg [31:0] next_pc;
    reg [31:0] instr_q;

    // 32-entry Register File
    reg [31:0] regfile [0:31];

    // CSRs
    reg [31:0] csr_mstatus;
    reg [31:0] csr_mie;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;

    assign imem_addr_o = pc_q;

    // Instruction Fields
    wire [6:0]  opcode = instr_q[6:0];
    wire [4:0]  rd     = instr_q[11:7];
    wire [2:0]  funct3 = instr_q[14:12];
    wire [4:0]  rs1    = instr_q[19:15];
    wire [4:0]  rs2    = instr_q[24:20];
    wire [6:0]  funct7 = instr_q[31:25];
    wire [11:0] csr_addr = instr_q[31:20];

    // Immediates
    wire [31:0] imm_i = {{20{instr_q[31]}}, instr_q[31:20]};
    wire [31:0] imm_s = {{20{instr_q[31]}}, instr_q[31:25], instr_q[11:7]};
    wire [31:0] imm_b = {{19{instr_q[31]}}, instr_q[31], instr_q[7], instr_q[30:25], instr_q[11:8], 1'b0};
    wire [31:0] imm_u = {instr_q[31:12], 12'd0};
    wire [31:0] imm_j = {{11{instr_q[31]}}, instr_q[31], instr_q[19:12], instr_q[20], instr_q[30:21], 1'b0};
    wire [31:0] imm_z = {27'd0, instr_q[19:15]};

    // Register Read
    wire [31:0] rs1_val = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    wire [31:0] rs2_val = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];

    // ALU Logic
    reg [31:0] alu_op_a;
    reg [31:0] alu_op_b;
    reg [31:0] alu_result;

    always @(*) begin
        case (opcode)
            `OPCODE_OP: begin
                alu_op_a = rs1_val;
                alu_op_b = rs2_val;
            end
            `OPCODE_OP_IMM: begin
                alu_op_a = rs1_val;
                alu_op_b = imm_i;
            end
            `OPCODE_LUI: begin
                alu_op_a = 32'd0;
                alu_op_b = imm_u;
            end
            `OPCODE_AUIPC: begin
                alu_op_a = pc_q;
                alu_op_b = imm_u;
            end
            `OPCODE_JAL, `OPCODE_JALR: begin
                alu_op_a = pc_q;
                alu_op_b = 32'd4;
            end
            default: begin
                alu_op_a = rs1_val;
                alu_op_b = imm_i;
            end
        endcase
    end

    // ALU Execution
    wire [4:0] shamt = alu_op_b[4:0];
    always @(*) begin
        case (opcode)
            `OPCODE_LUI, `OPCODE_AUIPC: begin
                alu_result = alu_op_a + alu_op_b;
            end
            `OPCODE_JAL, `OPCODE_JALR: begin
                alu_result = alu_op_a + alu_op_b; // return address PC + 4
            end
            `OPCODE_OP: begin
                case (funct3)
                    3'b000:  alu_result = funct7[5] ? (alu_op_a - alu_op_b) : (alu_op_a + alu_op_b);
                    3'b001:  alu_result = alu_op_a << shamt;
                    3'b010:  alu_result = ($signed(alu_op_a) < $signed(alu_op_b)) ? 32'd1 : 32'd0;
                    3'b011:  alu_result = (alu_op_a < alu_op_b) ? 32'd1 : 32'd0;
                    3'b100:  alu_result = alu_op_a ^ alu_op_b;
                    3'b101:  alu_result = funct7[5] ? ($signed(alu_op_a) >>> shamt) : (alu_op_a >> shamt);
                    3'b110:  alu_result = alu_op_a | alu_op_b;
                    3'b111:  alu_result = alu_op_a & alu_op_b;
                    default: alu_result = 32'd0;
                endcase
            end
            `OPCODE_OP_IMM: begin
                case (funct3)
                    3'b000:  alu_result = alu_op_a + alu_op_b;
                    3'b001:  alu_result = alu_op_a << shamt;
                    3'b010:  alu_result = ($signed(alu_op_a) < $signed(alu_op_b)) ? 32'd1 : 32'd0;
                    3'b011:  alu_result = (alu_op_a < alu_op_b) ? 32'd1 : 32'd0;
                    3'b100:  alu_result = alu_op_a ^ alu_op_b;
                    3'b101:  alu_result = funct7[5] ? ($signed(alu_op_a) >>> shamt) : (alu_op_a >> shamt);
                    3'b110:  alu_result = alu_op_a | alu_op_b;
                    3'b111:  alu_result = alu_op_a & alu_op_b;
                    default: alu_result = 32'd0;
                endcase
            end
            default: begin
                alu_result = alu_op_a + alu_op_b;
            end
        endcase
    end

    // Branch condition evaluation
    reg branch_taken;
    always @(*) begin
        case (funct3)
            `BR_BEQ:  branch_taken = (rs1_val == rs2_val);
            `BR_BNE:  branch_taken = (rs1_val != rs2_val);
            `BR_BLT:  branch_taken = ($signed(rs1_val) < $signed(rs2_val));
            `BR_BGE:  branch_taken = ($signed(rs1_val) >= $signed(rs2_val));
            `BR_BLTU: branch_taken = (rs1_val < rs2_val);
            `BR_BGEU: branch_taken = (rs1_val >= rs2_val);
            default:  branch_taken = 1'b0;
        endcase
    end

    // Load Data Extension
    reg [31:0] load_val;
    always @(*) begin
        case (funct3)
            `MEM_B: begin
                case (dmem_addr_o[1:0])
                    2'b00: load_val = {{24{dmem_rdata_i[7]}},  dmem_rdata_i[7:0]};
                    2'b01: load_val = {{24{dmem_rdata_i[15]}}, dmem_rdata_i[15:8]};
                    2'b10: load_val = {{24{dmem_rdata_i[23]}}, dmem_rdata_i[23:16]};
                    2'b11: load_val = {{24{dmem_rdata_i[31]}}, dmem_rdata_i[31:24]};
                endcase
            end
            `MEM_BU: begin
                case (dmem_addr_o[1:0])
                    2'b00: load_val = {24'd0, dmem_rdata_i[7:0]};
                    2'b01: load_val = {24'd0, dmem_rdata_i[15:8]};
                    2'b10: load_val = {24'd0, dmem_rdata_i[23:16]};
                    2'b11: load_val = {24'd0, dmem_rdata_i[31:24]};
                endcase
            end
            `MEM_H: begin
                if (dmem_addr_o[1])
                    load_val = {{16{dmem_rdata_i[31]}}, dmem_rdata_i[31:16]};
                else
                    load_val = {{16{dmem_rdata_i[15]}}, dmem_rdata_i[15:0]};
            end
            `MEM_HU: begin
                if (dmem_addr_o[1])
                    load_val = {16'd0, dmem_rdata_i[31:16]};
                else
                    load_val = {16'd0, dmem_rdata_i[15:0]};
            end
            default: begin // `MEM_W
                load_val = dmem_rdata_i;
            end
        endcase
    end

    // CSR Read multiplexer
    reg [31:0] csr_rdata;
    always @(*) begin
        case (csr_addr)
            `CSR_MSTATUS: csr_rdata = csr_mstatus;
            `CSR_MIE:     csr_rdata = csr_mie;
            `CSR_MTVEC:   csr_rdata = csr_mtvec;
            `CSR_MEPC:    csr_rdata = csr_mepc;
            `CSR_MCAUSE:  csr_rdata = csr_mcause;
            `CSR_MIP:     csr_rdata = {20'd0, ext_irq_i, 3'd0, timer_irq_i, 3'd0, uart_irq_i, 3'd0};
            default:      csr_rdata = 32'd0;
        endcase
    end

    // Interrupt pending check (M-mode)
    wire mstatus_mie = csr_mstatus[3];
    wire irq_timer_pending = csr_mie[7]  & timer_irq_i;
    wire irq_ext_pending   = csr_mie[11] & ext_irq_i;
    wire irq_uart_pending  = csr_mie[3]  & uart_irq_i;
    wire irq_pending       = mstatus_mie & (irq_timer_pending | irq_ext_pending | irq_uart_pending);

    // Initial register reset helper
    integer r;

    // Main CPU Control & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q            <= STATE_FETCH;
            pc_q               <= RESET_VEC;
            instr_q            <= 32'd0;
            imem_req_o         <= 1'b1;
            dmem_req_o         <= 1'b0;
            dmem_we_o          <= 1'b0;
            dmem_addr_o        <= 32'd0;
            dmem_wdata_o       <= 32'd0;
            dmem_wstrb_o       <= 4'b0000;
            instr_retire_o     <= 1'b0;
            evt_load_o         <= 1'b0;
            evt_store_o        <= 1'b0;
            evt_fetch_o        <= 1'b1; // First fetch on reset exit
            evt_branch_jump_o  <= 1'b0;
            evt_stall_bubble_o <= 1'b0;
            evt_exception_o    <= 1'b0;
            csr_mstatus        <= 32'h0000_1800; // MPP = 2'b11
            csr_mie            <= 32'd0;
            csr_mtvec          <= 32'h0000_0000;
            csr_mepc           <= 32'd0;
            csr_mcause         <= 32'd0;
            for (r = 0; r < 32; r = r + 1) begin
                regfile[r] <= 32'd0;
            end
        end else begin
            // Default 1-cycle pulses
            instr_retire_o     <= 1'b0;
            evt_load_o         <= 1'b0;
            evt_store_o        <= 1'b0;
            evt_fetch_o        <= 1'b0;
            evt_branch_jump_o  <= 1'b0;
            evt_stall_bubble_o <= 1'b0;
            evt_exception_o    <= 1'b0;

            case (state_q)
                //-------------------------------------------------------------
                // FETCH: Wait for instruction from IMEM
                //-------------------------------------------------------------
                STATE_FETCH: begin
                    imem_req_o <= 1'b1;
                    if (imem_ready_i) begin
                        instr_q    <= imem_rdata_i;
                        imem_req_o <= 1'b0;
                        state_q    <= STATE_DECODE_EX;
                    end else begin
                        evt_stall_bubble_o <= 1'b1; // Waiting for imem
                    end
                end

                //-------------------------------------------------------------
                // DECODE / EXECUTE: Single-cycle execution or initiate Memory
                //-------------------------------------------------------------
                STATE_DECODE_EX: begin
                    case (opcode)
                        // ALU / Immediate Instructions
                        `OPCODE_OP, `OPCODE_OP_IMM, `OPCODE_LUI, `OPCODE_AUIPC: begin
                            if (rd != 5'd0) begin
                                regfile[rd] <= alu_result;
                            end
                            pc_q           <= pc_q + 32'd4;
                            instr_retire_o <= 1'b1;
                            imem_req_o     <= 1'b1;
                            evt_fetch_o    <= 1'b1;
                            state_q        <= STATE_FETCH;
                        end

                        // Jump and Link (JAL)
                        `OPCODE_JAL: begin
                            if (rd != 5'd0) begin
                                regfile[rd] <= pc_q + 32'd4;
                            end
                            pc_q              <= pc_q + imm_j;
                            instr_retire_o    <= 1'b1;
                            evt_branch_jump_o <= 1'b1;
                            imem_req_o        <= 1'b1;
                            evt_fetch_o       <= 1'b1;
                            state_q           <= STATE_FETCH;
                        end

                        // Jump and Link Register (JALR)
                        `OPCODE_JALR: begin
                            if (rd != 5'd0) begin
                                regfile[rd] <= pc_q + 32'd4;
                            end
                            pc_q              <= (rs1_val + imm_i) & ~32'd1;
                            instr_retire_o    <= 1'b1;
                            evt_branch_jump_o <= 1'b1;
                            imem_req_o        <= 1'b1;
                            evt_fetch_o       <= 1'b1;
                            state_q           <= STATE_FETCH;
                        end

                        // Conditional Branches
                        `OPCODE_BRANCH: begin
                            if (branch_taken) begin
                                pc_q              <= pc_q + imm_b;
                                evt_branch_jump_o <= 1'b1;
                            end else begin
                                pc_q <= pc_q + 32'd4;
                            end
                            instr_retire_o <= 1'b1;
                            imem_req_o     <= 1'b1;
                            evt_fetch_o    <= 1'b1;
                            state_q        <= STATE_FETCH;
                        end

                        // Memory Loads
                        `OPCODE_LOAD: begin
                            dmem_req_o  <= 1'b1;
                            dmem_we_o   <= 1'b0;
                            dmem_addr_o <= rs1_val + imm_i;
                            dmem_wstrb_o<= 4'b0000;
                            evt_load_o  <= 1'b1;
                            state_q     <= STATE_MEM_WAIT;
                        end

                        // Memory Stores
                        `OPCODE_STORE: begin
                            dmem_req_o  <= 1'b1;
                            dmem_we_o   <= 1'b1;
                            dmem_addr_o <= rs1_val + imm_s;
                            case (funct3)
                                `MEM_B: begin
                                    case (rs1_val[1:0] + imm_s[1:0])
                                        2'b00: begin dmem_wdata_o <= {24'd0, rs2_val[7:0]};       dmem_wstrb_o <= 4'b0001; end
                                        2'b01: begin dmem_wdata_o <= {16'd0, rs2_val[7:0], 8'd0};  dmem_wstrb_o <= 4'b0010; end
                                        2'b10: begin dmem_wdata_o <= {8'd0, rs2_val[7:0], 16'd0}; dmem_wstrb_o <= 4'b0100; end
                                        2'b11: begin dmem_wdata_o <= {rs2_val[7:0], 24'd0};       dmem_wstrb_o <= 4'b1000; end
                                    endcase
                                end
                                `MEM_H: begin
                                    if ((rs1_val[1:0] + imm_s[1:0]) >= 2'b10) begin
                                        dmem_wdata_o <= {rs2_val[15:0], 16'd0};
                                        dmem_wstrb_o <= 4'b1100;
                                    end else begin
                                        dmem_wdata_o <= {16'd0, rs2_val[15:0]};
                                        dmem_wstrb_o <= 4'b0011;
                                    end
                                end
                                default: begin // `MEM_W
                                    dmem_wdata_o <= rs2_val;
                                    dmem_wstrb_o <= 4'b1111;
                                end
                            endcase
                            evt_store_o <= 1'b1;
                            state_q     <= STATE_MEM_WAIT;
                        end

                        // System / CSR Instructions
                        `OPCODE_SYSTEM: begin
                            if (funct3 == 3'b000) begin
                                if (instr_q[31:20] == 12'h302) begin
                                    // MRET
                                    pc_q           <= csr_mepc;
                                    csr_mstatus[3] <= csr_mstatus[7]; // MIE <= MPIE
                                    csr_mstatus[7] <= 1'b1;           // MPIE <= 1
                                    instr_retire_o <= 1'b1;
                                    imem_req_o     <= 1'b1;
                                    evt_fetch_o    <= 1'b1;
                                    state_q        <= STATE_FETCH;
                                end else begin
                                    // ECALL / EBREAK / Trap
                                    csr_mepc        <= pc_q;
                                    csr_mcause      <= 32'd11; // Machine ECALL
                                    csr_mstatus[7]  <= csr_mstatus[3];
                                    csr_mstatus[3]  <= 1'b0;
                                    pc_q            <= csr_mtvec;
                                    instr_retire_o  <= 1'b1;
                                    evt_exception_o <= 1'b1;
                                    imem_req_o      <= 1'b1;
                                    evt_fetch_o     <= 1'b1;
                                    state_q         <= STATE_FETCH;
                                end
                            end else begin
                                // CSRRW, CSRRS, CSRRC
                                if (rd != 5'd0) begin
                                    regfile[rd] <= csr_rdata;
                                end
                                case (funct3[1:0])
                                    2'b01: begin // CSRRW
                                        case (csr_addr)
                                            `CSR_MSTATUS: csr_mstatus <= funct3[2] ? imm_z : rs1_val;
                                            `CSR_MIE:     csr_mie     <= funct3[2] ? imm_z : rs1_val;
                                            `CSR_MTVEC:   csr_mtvec   <= funct3[2] ? imm_z : rs1_val;
                                            `CSR_MEPC:    csr_mepc    <= funct3[2] ? imm_z : rs1_val;
                                            `CSR_MCAUSE:  csr_mcause  <= funct3[2] ? imm_z : rs1_val;
                                        endcase
                                    end
                                    2'b10: begin // CSRRS
                                        case (csr_addr)
                                            `CSR_MSTATUS: csr_mstatus <= csr_mstatus | (funct3[2] ? imm_z : rs1_val);
                                            `CSR_MIE:     csr_mie     <= csr_mie     | (funct3[2] ? imm_z : rs1_val);
                                            `CSR_MTVEC:   csr_mtvec   <= csr_mtvec   | (funct3[2] ? imm_z : rs1_val);
                                            `CSR_MEPC:    csr_mepc    <= csr_mepc    | (funct3[2] ? imm_z : rs1_val);
                                            `CSR_MCAUSE:  csr_mcause  <= csr_mcause  | (funct3[2] ? imm_z : rs1_val);
                                        endcase
                                    end
                                    2'b11: begin // CSRRC
                                        case (csr_addr)
                                            `CSR_MSTATUS: csr_mstatus <= csr_mstatus & ~(funct3[2] ? imm_z : rs1_val);
                                            `CSR_MIE:     csr_mie     <= csr_mie     & ~(funct3[2] ? imm_z : rs1_val);
                                            `CSR_MTVEC:   csr_mtvec   <= csr_mtvec   & ~(funct3[2] ? imm_z : rs1_val);
                                            `CSR_MEPC:    csr_mepc    <= csr_mepc    & ~(funct3[2] ? imm_z : rs1_val);
                                            `CSR_MCAUSE:  csr_mcause  <= csr_mcause  & ~(funct3[2] ? imm_z : rs1_val);
                                        endcase
                                    end
                                endcase
                                pc_q           <= pc_q + 32'd4;
                                instr_retire_o <= 1'b1;
                                imem_req_o     <= 1'b1;
                                evt_fetch_o    <= 1'b1;
                                state_q        <= STATE_FETCH;
                            end
                        end

                        // FENCE / NOP
                        default: begin
                            pc_q           <= pc_q + 32'd4;
                            instr_retire_o <= 1'b1;
                            imem_req_o     <= 1'b1;
                            evt_fetch_o    <= 1'b1;
                            state_q        <= STATE_FETCH;
                        end
                    endcase
                end

                //-------------------------------------------------------------
                // MEM_WAIT: Wait for DMEM / Peripheral transaction to finish
                //-------------------------------------------------------------
                STATE_MEM_WAIT: begin
                    if (dmem_ready_i) begin
                        dmem_req_o <= 1'b0;
                        if (!dmem_we_o && (rd != 5'd0)) begin
                            regfile[rd] <= load_val;
                        end
                        pc_q           <= pc_q + 32'd4;
                        instr_retire_o <= 1'b1;

                        // Check pending interrupt at instruction boundary
                        if (irq_pending) begin
                            state_q <= STATE_TRAP;
                        end else begin
                            imem_req_o  <= 1'b1;
                            evt_fetch_o <= 1'b1;
                            state_q     <= STATE_FETCH;
                        end
                    end else begin
                        evt_stall_bubble_o <= 1'b1; // Memory wait cycle
                    end
                end

                //-------------------------------------------------------------
                // TRAP: Take pending interrupt
                //-------------------------------------------------------------
                STATE_TRAP: begin
                    csr_mepc        <= pc_q;
                    csr_mstatus[7]  <= csr_mstatus[3]; // MPIE <= MIE
                    csr_mstatus[3]  <= 1'b0;           // MIE <= 0
                    if (irq_ext_pending)
                        csr_mcause  <= 32'h8000_000B; // Machine External Interrupt
                    else if (irq_timer_pending)
                        csr_mcause  <= 32'h8000_0007; // Machine Timer Interrupt
                    else
                        csr_mcause  <= 32'h8000_0003; // Machine Software/UART Interrupt
                    pc_q            <= csr_mtvec;
                    evt_exception_o <= 1'b1;
                    imem_req_o      <= 1'b1;
                    evt_fetch_o     <= 1'b1;
                    state_q         <= STATE_FETCH;
                end
            endcase
        end
    end

endmodule
