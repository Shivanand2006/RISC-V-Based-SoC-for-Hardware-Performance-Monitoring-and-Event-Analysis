/* -----------------------------------------------------------------------------
 * Project        : AXI-lite UART IP Core
 * File           : axi_uart_defines.vh
 * Description    : AXI interface defines for the AXI-UART IP Core
 * -----------------------------------------------------------------------------
 * AXI Interface Width Defines
 * -----------------------------------------------------------------------------*/

`ifndef AXI_UART_DEFINES_VH
`define AXI_UART_DEFINES_VH

// AXI data bus width (32-bit)
`define _AXI_UART_DATA_WIDTH_   32

// AXI address bus width (8-bit: covers 64 register locations)
`define _AXI_UART_ADDR_WIDTH_   8

// AXI ID field width
`define _AXI_UART_ID_WIDTH_     4

// AXI response field width (OKAY, EXOKAY, SLVERR, DECERR)
`define _AXI_UART_RESP_WIDTH_   2

// Baudrate divisor register width (16-bit for wide baud range)
`define _AXI_UART_DIV_WIDTH_    16

// Internal FIFO depth (16 entries - standard 16550 UART FIFO)
`define _AXI_UART_FIFO_DEPTH_   16

// Deadlock detection limit (counter to escape stuck AXI transactions)
`define _AXI_UART_DEADLOCK_     256

`endif // AXI_UART_DEFINES_VH
