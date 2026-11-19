//=============================================================================
// File: gpio_defines.vh
// Description: Header and register definitions for GPIO peripheral
//=============================================================================

`ifndef GPIO_DEFINES_VH
`define GPIO_DEFINES_VH

// Register Byte Offsets
`define GPIO_REG_DIR         8'h00 // Direction (1 = output, 0 = input)
`define GPIO_REG_OUT         8'h04 // Output data register
`define GPIO_REG_IN          8'h08 // Input data register (read-only, synchronized)

`endif // GPIO_DEFINES_VH
