//=============================================================================
// File: interconnect_defines.vh
// Description: Base addresses and size definitions for SoC Interconnect / Decoder
//=============================================================================

`ifndef INTERCONNECT_DEFINES_VH
`define INTERCONNECT_DEFINES_VH

// Base addresses (32-bit)
`define ADDR_IMEM_BASE        32'h0000_0000
`define ADDR_IMEM_MASK        32'hFFFF_F000 // 4KB

`define ADDR_DMEM_BASE        32'h0000_1000
`define ADDR_DMEM_MASK        32'hFFFF_F000 // 4KB

`define ADDR_UART_BASE        32'h0000_2000
`define ADDR_UART_MASK        32'hFFFF_FF00 // 256B

`define ADDR_TIMER_BASE       32'h0000_2100
`define ADDR_TIMER_MASK       32'hFFFF_FF00 // 256B

`define ADDR_GPIO_BASE        32'h0000_2200
`define ADDR_GPIO_MASK        32'hFFFF_FF00 // 256B

`define ADDR_CYCLE_CNT_BASE   32'h0000_2300
`define ADDR_CYCLE_CNT_MASK   32'hFFFF_FF00 // 256B

`define ADDR_INSTR_CNT_BASE   32'h0000_2400
`define ADDR_INSTR_CNT_MASK   32'hFFFF_FF00 // 256B

`define ADDR_EVENT_CNT_BASE   32'h0000_2500
`define ADDR_EVENT_CNT_MASK   32'hFFFF_FF00 // 256B

`endif // INTERCONNECT_DEFINES_VH
