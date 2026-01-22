/* IronCore Linker Script
 * Memory layout for bare-metal RV32IM
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

/* Memory Map */
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
}

/* Stack at top of RAM */
__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* Code section - starts at ROM */
    .text : {
        *(.text.init)
        *(.text.trap)
        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > ROM

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        . = ALIGN(4);
    } > ROM

    /* Data section - loaded to RAM */
    .data : {
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT > ROM

    __data_load = LOADADDR(.data);

    /* BSS section */
    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /* Heap starts after BSS */
    __heap_start = .;
}
