//=============================================================================
// File: uart_defines.vh
// Description: Header and register definitions for UART peripheral (16550 subset)
//=============================================================================

`ifndef UART_DEFINES_VH
`define UART_DEFINES_VH

// Register Byte Offsets
`define UART_REG_RBR_THR     8'h00 // RBR (RO), THR (WO)
`define UART_REG_IER         8'h04 // Interrupt Enable Register
`define UART_REG_DIVISOR     8'h08 // Baud Divisor Register
`define UART_REG_LCR         8'h0C // Line Control Register
`define UART_REG_LSR         8'h14 // Line Status Register

// LSR Bit fields
`define UART_LSR_DR_BIT      0     // Data Ready (Rx character available)
`define UART_LSR_THRE_BIT    5     // Transmitter Holding Register Empty
`define UART_LSR_TEMT_BIT    6     // Transmitter Empty

// IER Bit fields
`define UART_IER_RX_BIT      0     // Received Data Available Interrupt
`define UART_IER_TX_BIT      1     // Transmitter Holding Register Empty Interrupt

`endif // UART_DEFINES_VH
