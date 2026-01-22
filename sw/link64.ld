/* IronCore Linker Script for RV64
 * Code and Data in RAM at 0x80000000
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}

/* Stack at top of RAM */
__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* Code section */
    .text : {
        *(.text.init)
        *(.text.trap)
        *(.text)
        *(.text.*)
        . = ALIGN(8);
    } > RAM

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        . = ALIGN(8);
    } > RAM

    /* Data section */
    .data : {
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(8);
        __data_end = .;
    } > RAM

    __data_load = LOADADDR(.data);

    /* BSS section */
    .bss 0x80002000 : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(8);
        __bss_end = .;
    } > RAM
    
    __heap_start = .;
}
