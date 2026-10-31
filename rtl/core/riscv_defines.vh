//=============================================================================
// File: riscv_defines.vh
// Description: RV32I Opcodes, funct3, funct7, ALU controls, and CSR addresses
//=============================================================================

`ifndef RISCV_DEFINES_VH
`define RISCV_DEFINES_VH

// Major Opcodes (RV32I)
`define OPCODE_OP         7'b0110011 // Register-Register ALU
`define OPCODE_OP_IMM     7'b0010011 // Register-Immediate ALU
`define OPCODE_LUI        7'b0110111 // Load Upper Immediate
`define OPCODE_AUIPC      7'b0010111 // Add Upper Immediate to PC
`define OPCODE_JAL        7'b1101111 // Jump and Link
`define OPCODE_JALR       7'b1100111 // Jump and Link Register
`define OPCODE_BRANCH     7'b1100011 // Conditional Branches
`define OPCODE_LOAD       7'b0000011 // Load Instructions
`define OPCODE_STORE      7'b0100011 // Store Instructions
`define OPCODE_SYSTEM     7'b1110011 // System / CSR / ECALL / EBREAK / MRET
`define OPCODE_MISC_MEM   7'b0001111 // FENCE

// ALU Control Operations
`define ALU_ADD           4'd0
`define ALU_SUB           4'd1
`define ALU_AND           4'd2
`define ALU_OR            4'd3
`define ALU_XOR           4'd4
`define ALU_SLT           4'd5
`define ALU_SLTU          4'd6
`define ALU_SLL           4'd7
`define ALU_SRL           4'd8
`define ALU_SRA           4'd9
`define ALU_COPY_B        4'd10

// Branch Types (funct3)
`define BR_BEQ            3'b000
`define BR_BNE            3'b001
`define BR_BLT            3'b100
`define BR_BGE            3'b101
`define BR_BLTU           3'b110
`define BR_BGEU           3'b111

// Memory Load/Store Types (funct3)
`define MEM_B             3'b000
`define MEM_H             3'b001
`define MEM_W             3'b010
`define MEM_BU            3'b100
`define MEM_HU            3'b101

// CSR Addresses (Machine Mode)
`define CSR_MSTATUS       12'h300
`define CSR_MIE           12'h304
`define CSR_MTVEC         12'h305
`define CSR_MEPC          12'h341
`define CSR_MCAUSE        12'h342
`define CSR_MIP           12'h344

`endif // RISCV_DEFINES_VH
