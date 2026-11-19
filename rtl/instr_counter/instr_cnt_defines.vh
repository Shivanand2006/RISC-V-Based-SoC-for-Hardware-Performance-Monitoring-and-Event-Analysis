//=============================================================================
// File: instr_cnt_defines.vh
// Description: Header and register definitions for Instruction Counter IP
//=============================================================================

`ifndef INSTR_CNT_DEFINES_VH
`define INSTR_CNT_DEFINES_VH

// Register Byte Offsets
`define INSTR_CNT_REG_CTRL       8'h00
`define INSTR_CNT_REG_STATUS     8'h04
`define INSTR_CNT_REG_CNT_LO     8'h08
`define INSTR_CNT_REG_CNT_HI     8'h0C

// Bit fields in CTRL register
`define INSTR_CNT_CTRL_EN_BIT    0
`define INSTR_CNT_CTRL_CLR_BIT   1

// Bit fields in STATUS register
`define INSTR_CNT_STATUS_RUN_BIT 0

`endif // INSTR_CNT_DEFINES_VH
