ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
}

SECTIONS
{
    . = ORIGIN(IMEM);
    .text : ALIGN(4) { KEEP(*(.text.init)) *(.text .text.*) } > IMEM
    .rodata : ALIGN(4) { *(.rodata .rodata.*) } > IMEM

    . = ORIGIN(DMEM);
    .data : ALIGN(4) { *(.data .data.*) } > DMEM
    .bss (NOLOAD) : ALIGN(4) { *(.bss .bss.* COMMON) } > DMEM
    . = ALIGN(16);
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM) - 16;
}
