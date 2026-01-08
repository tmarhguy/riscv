/* IronCore Test Linker Script */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 16K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > ROM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > ROM

    .data : {
        *(.data)
        *(.data.*)
    } > RAM AT > ROM

    .bss : {
        *(.bss)
        *(.bss.*)
    } > RAM

    /* Test result area */
    .tohost 0x80001000 : {
        *(.tohost)
    }
}
