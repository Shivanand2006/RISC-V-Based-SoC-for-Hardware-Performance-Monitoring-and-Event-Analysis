/* -----------------------------------------------------------------------------
 * Project        : AXI-lite UART IP Core
 * File           : axi_uart.vh
 * Description    : UART register map and configuration bit field defines
 *                  Compatible with 16550-style UART register layout.
 * -----------------------------------------------------------------------------
 * Register Map (word-addressed, bits [ADDR_WIDTH-1:LSB_WIDTH])
 *   0x00 : RBR  - Receiver Buffer Register  (Read,  DLAB=0)
 *   0x00 : THR  - Transmitter Holding Reg   (Write, DLAB=0)
 *   0x01 : IER  - Interrupt Enable Register (R/W,   DLAB=0)
 *   0x01 : DLL  - Divisor Latch LSB         (R/W,   DLAB=1) -> mapped as BAUD_DIVISOR
 *   0x03 : LCR  - Line Control Register     (R/W)
 *   0x05 : LSR  - Line Status Register      (Read)
 * -----------------------------------------------------------------------------*/

`ifndef AXI_UART_VH
`define AXI_UART_VH

// -----------------------------------------------------------------------
// Register Addresses (word index: addr[ADDR_WIDTH-1 : LSB_WIDTH])
// With AXI_DATA_WIDTH=32, LSB_WIDTH=2, so byte addr >> 2
//   RBR/THR  -> byte 0x00 -> word index 0
//   IER/DLL  -> byte 0x04 -> word index 1
//   LCR      -> byte 0x0C -> word index 3
//   LSR      -> byte 0x14 -> word index 5
// -----------------------------------------------------------------------
`define _UART_RBR_              3'h0    // Receiver Buffer Register  (DLAB=0)
`define _UART_THR_              3'h0    // Transmitter Holding Reg   (DLAB=0)
`define _UART_IER_              3'h1    // Interrupt Enable Register (DLAB=0)
`define _UART_BAUD_DIVISOR_     3'h1    // Baud Divisor Latch        (DLAB=1)
`define _UART_LCR_              3'h3    // Line Control Register
`define _UART_LSR_              3'h5    // Line Status Register

// -----------------------------------------------------------------------
// LCR Bit Field Positions (within the 32-bit config register)
// -----------------------------------------------------------------------
`define _UART_CONFIG_DLAB_          7   // Divisor Latch Access Bit
`define _UART_CONFIG_STOP_BITS_     2   // Stop bits select (0=1 stop, 1=2 stop)
`define _UART_CONFIG_PARITY_EN_     3   // Parity Enable
`define _UART_CONFIG_PARITY_MODE_   4   // Parity Mode (0=odd, 1=even)

// -----------------------------------------------------------------------
// LSR Bit Field Positions (within the 32-bit status register)
// -----------------------------------------------------------------------
`define _UART_LSR_DATA_READY_   0   // Receiver data ready
`define _UART_LSR_THRE_         5   // Transmitter Holding Register Empty
`define _UART_LSR_TEMT_         6   // Transmitter Empty (shift reg + THR empty)

// -----------------------------------------------------------------------
// UART Data Width
// -----------------------------------------------------------------------
`define _DATA_WIDTH_UART_       8   // Standard 8-bit UART data

// -----------------------------------------------------------------------
// Default Baud Rate Divisor
// Formula: divisor = clk_freq / (baud_rate * 16)
// Example: 50 MHz clock, 115200 baud -> 50_000_000 / (115200*16) = ~27
// -----------------------------------------------------------------------
`define _UART_BAUDRATE_DIV_INIT_    16'h001B    // 27 decimal -> 115200 bps @ 50 MHz

`endif // AXI_UART_VH
