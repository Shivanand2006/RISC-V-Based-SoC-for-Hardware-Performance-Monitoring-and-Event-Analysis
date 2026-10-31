//=============================================================================
// File: cycle_cnt_defines.vh
// Description: Header and register definitions for Cycle Counter IP
//=============================================================================

`ifndef CYCLE_CNT_DEFINES_VH
`define CYCLE_CNT_DEFINES_VH

// Register Byte Offsets
`define CYCLE_CNT_REG_CTRL       8'h00
`define CYCLE_CNT_REG_STATUS     8'h04
`define CYCLE_CNT_REG_CNT_LO     8'h08
`define CYCLE_CNT_REG_CNT_HI     8'h0C

// Bit fields in CTRL register
`define CYCLE_CNT_CTRL_EN_BIT    0
`define CYCLE_CNT_CTRL_CLR_BIT   1

// Bit fields in STATUS register
`define CYCLE_CNT_STATUS_RUN_BIT 0

`endif // CYCLE_CNT_DEFINES_VH
