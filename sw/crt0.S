# IronCore C Runtime Startup
# Minimal startup code for bare-metal RV32IM

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
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:

    # Copy initialized data from ROM to RAM
    la      t0, __data_load
    la      t1, __data_start
    la      t2, __data_end
3:
    bge     t1, t2, 4f
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
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
    addi    sp, sp, -64
    sw      ra, 0(sp)
    sw      t0, 4(sp)
    sw      t1, 8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)

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
    lw      ra, 0(sp)
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    addi    sp, sp, 64

    mret


# Weak symbol for global pointer
.weak __global_pointer$
__global_pointer$ = __data_start + 0x800
