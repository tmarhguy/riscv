# IronCore C Runtime Startup for RV64
# Minimal startup code for bare-metal RV64IM

.section .text.init
.global _start
.type _start, @function

_start:
    # Disable interrupts
    csrw    mie, zero

    # Set up stack pointer
    la      sp, __stack_top

    # Set up global pointer
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    # Clear BSS section
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bge     t0, t1, 2f
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       1b
2:

    # Copy initialized data from ROM to RAM
    la      t0, __data_load
    la      t1, __data_start
    la      t2, __data_end
3:
    bge     t1, t2, 4f
    ld      t3, 0(t0)
    sd      t3, 0(t1)
    addi    t0, t0, 8
    addi    t1, t1, 8
    j       3b
4:

    # Set up trap handler
    la      t0, _trap_handler
    csrw    mtvec, t0

    # Call main
    call    main

    # If main returns, loop forever
_halt:
    j       _halt


# Trap handler
.section .text.trap
.global _trap_handler
.type _trap_handler, @function
.align 4

_trap_handler:
    # Save context (minimal)
    addi    sp, sp, -128
    sd      ra, 0(sp)
    sd      t0, 8(sp)
    sd      t1, 16(sp)
    sd      t2, 24(sp)
    sd      a0, 32(sp)
    sd      a1, 40(sp)
    sd      a2, 48(sp)
    sd      a3, 56(sp)
    sd      a4, 64(sp)
    sd      a5, 72(sp)

    # Read cause
    csrr    a0, mcause

    # Check if it's an exception or interrupt
    bltz    a0, _interrupt_handler

_exception_handler:
    # Handle exception
    # For now, just increment mepc and return
    csrr    t0, mepc
    addi    t0, t0, 4
    csrw    mepc, t0
    j       _trap_exit

_interrupt_handler:
    # Handle interrupt (not implemented yet)
    j       _trap_exit

_trap_exit:
    # Restore context
    ld      ra, 0(sp)
    ld      t0, 8(sp)
    ld      t1, 16(sp)
    ld      t2, 24(sp)
    ld      a0, 32(sp)
    ld      a1, 40(sp)
    ld      a2, 48(sp)
    ld      a3, 56(sp)
    ld      a4, 64(sp)
    ld      a5, 72(sp)
    addi    sp, sp, 128

    mret


# Weak symbol for global pointer
.weak __global_pointer$
__global_pointer$ = __data_start + 0x800
