//=============================================================================
// File: event_cnt_defines.vh
// Description: Header and register definitions for Performance Event Counter IP
//=============================================================================

`ifndef EVENT_CNT_DEFINES_VH
`define EVENT_CNT_DEFINES_VH

// Register Byte Offsets
`define EVENT_CNT_REG_CTRL       8'h00
`define EVENT_CNT_REG_EVT_SEL    8'h04
`define EVENT_CNT_REG_COUNT      8'h08
`define EVENT_CNT_REG_THRESH     8'h0C
`define EVENT_CNT_REG_STATUS     8'h10

// Bit fields in CTRL register
`define EVENT_CNT_CTRL_EN_BIT    0
`define EVENT_CNT_CTRL_CLR_BIT   1
`define EVENT_CNT_CTRL_IRQEN_BIT 2

// Bit fields in STATUS register
`define EVENT_CNT_STATUS_OVF_BIT    0
`define EVENT_CNT_STATUS_THRHIT_BIT 1
`define EVENT_CNT_STATUS_RUN_BIT    2

// Event Selection Encoding
`define EVENT_SEL_LOAD           3'd0 // Data-memory read request accepted (load)
`define EVENT_SEL_STORE          3'd1 // Data-memory write request accepted (store)
`define EVENT_SEL_FETCH          3'd2 // Instruction fetch request accepted
`define EVENT_SEL_BRANCH_JUMP    3'd3 // Branch / jump taken
`define EVENT_SEL_STALL_BUBBLE   3'd4 // Pipeline stall or bubble cycle
`define EVENT_SEL_EXCEPTION      3'd5 // Exception / trap taken
`define EVENT_SEL_TIMER_IRQ      3'd6 // Timer interrupt event
`define EVENT_SEL_UART_TX        3'd7 // UART transmit-complete event

`endif // EVENT_CNT_DEFINES_VH
