/*=============================================================================
 * File: link.ld
 * Description: Linker script for RISC-V Hardware Performance Monitor SoC
 *              IMEM: 0x0000_0000 - 0x0000_0FFF (4 KB)
 *              DMEM: 0x0000_1000 - 0x0000_1FFF (4 KB)
 *============================================================================*/

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4096
    DMEM (rw)  : ORIGIN = 0x00001000, LENGTH = 4096
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > IMEM

    _data_load = LOADADDR(.data);

    .data : AT(_etext)
    {
        . = ALIGN(4);
        _data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _data_end = .;
    } > DMEM

    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > DMEM

    /* Stack top at end of DMEM (0x0000_2000) */
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
    }
}
