OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 8K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > IMEM

    .data : ALIGN(4)
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > DMEM

    .bss (NOLOAD) : ALIGN(4)
    {
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
    } > DMEM

    . = ALIGN(16);
    _end = .;
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.riscv.attributes)
    }
}
