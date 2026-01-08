# IronCore Trap Tests
# Verifies exception handling and CSR operations

#include "test_macros.h"

# Override default macros for trap testing
.section .text.init
.global _start
_start:
    # Set up stack
    la      sp, _stack_top

    # Set up trap handler
    la      t0, trap_handler
    csrw    mtvec, t0

    # Initialize trap counter
    li      x25, 0              # Trap count
    li      x26, 0              # Expected trap cause
    li      x27, 0              # Trap handled flag

    j       test_start

#-----------------------------------------------------------------------------
# Trap Handler
#-----------------------------------------------------------------------------
.align 4
trap_handler:
    # Save registers
    addi    sp, sp, -16
    sw      t0, 0(sp)
    sw      t1, 4(sp)
    sw      t2, 8(sp)

    # Increment trap counter
    addi    x25, x25, 1

    # Read cause
    csrr    t0, mcause

    # Check if cause matches expected
    bne     t0, x26, trap_unexpected

    # Mark trap as handled
    li      x27, 1

    # Skip faulting instruction (advance mepc by 4)
    csrr    t1, mepc
    addi    t1, t1, 4
    csrw    mepc, t1

    j       trap_return

trap_unexpected:
    # Unexpected trap - still advance mepc to avoid infinite loop
    csrr    t1, mepc
    addi    t1, t1, 4
    csrw    mepc, t1

trap_return:
    # Restore registers
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    addi    sp, sp, 16
    mret

#-----------------------------------------------------------------------------
# Test Start
#-----------------------------------------------------------------------------
test_start:

#-----------------------------------------------------------------------------
# Test 1: ECALL trap
#-----------------------------------------------------------------------------
test_1:
    li      x26, 11             # Expected cause: ECALL from M-mode
    li      x27, 0              # Clear handled flag
    ecall                       # Trigger trap
    # Check trap was handled
    li      t0, 1
    bne     x27, t0, test_fail_trap
    li      x30, 1

#-----------------------------------------------------------------------------
# Test 2: EBREAK trap
#-----------------------------------------------------------------------------
test_2:
    li      x26, 3              # Expected cause: Breakpoint
    li      x27, 0
    ebreak                      # Trigger trap
    li      t0, 1
    bne     x27, t0, test_fail_trap
    li      x30, 2

#-----------------------------------------------------------------------------
# Test 3: Illegal instruction trap
#-----------------------------------------------------------------------------
test_3:
    li      x26, 2              # Expected cause: Illegal instruction
    li      x27, 0
    .word   0x00000000          # Invalid instruction (all zeros)
    li      t0, 1
    bne     x27, t0, test_fail_trap
    li      x30, 3

#-----------------------------------------------------------------------------
# Test 4: CSR read/write (mtvec)
#-----------------------------------------------------------------------------
test_4:
    la      t0, trap_handler
    csrw    mtvec, t0           # Write mtvec
    csrr    t1, mtvec           # Read it back
    bne     t0, t1, test_fail_trap
    li      x30, 4

#-----------------------------------------------------------------------------
# Test 5: CSR read/write (mscratch - using mepc as scratch)
#-----------------------------------------------------------------------------
test_5:
    li      t0, 0x12340000
    csrw    mepc, t0            # Write test value
    csrr    t1, mepc            # Read back
    # Note: mepc may mask lower bits for alignment
    srli    t0, t0, 2
    slli    t0, t0, 2           # Clear lower 2 bits
    bne     t0, t1, test_fail_trap
    li      x30, 5

#-----------------------------------------------------------------------------
# Test 6: CSRRS (set bits)
#-----------------------------------------------------------------------------
test_6:
    li      t0, 0x00000000
    csrw    mie, t0             # Clear mie
    li      t1, 0x00000080      # Bit to set
    csrrs   t2, mie, t1         # Set bit, get old value
    bne     t2, t0, test_fail_trap  # Old value should be 0
    csrr    t3, mie             # Read new value
    bne     t3, t1, test_fail_trap  # Should have bit set
    li      x30, 6

#-----------------------------------------------------------------------------
# Test 7: CSRRC (clear bits)
#-----------------------------------------------------------------------------
test_7:
    li      t0, 0x000000FF
    csrw    mie, t0             # Set mie to 0xFF
    li      t1, 0x0000000F      # Bits to clear
    csrrc   t2, mie, t1         # Clear bits, get old value
    bne     t2, t0, test_fail_trap  # Old value should be 0xFF
    csrr    t3, mie             # Read new value
    li      t4, 0x000000F0      # Expected: 0xF0
    bne     t3, t4, test_fail_trap
    li      x30, 7

#-----------------------------------------------------------------------------
# Test 8: mcause preserved across traps
#-----------------------------------------------------------------------------
test_8:
    li      x26, 11             # ECALL
    ecall
    csrr    t0, mcause
    li      t1, 11
    bne     t0, t1, test_fail_trap
    li      x30, 8

#-----------------------------------------------------------------------------
# Test 9: Multiple traps
#-----------------------------------------------------------------------------
test_9:
    li      x25, 0              # Reset trap counter
    li      x26, 11             # ECALL
    ecall
    ecall
    ecall
    # Should have 3 traps
    li      t0, 3
    bne     x25, t0, test_fail_trap
    li      x30, 9

#-----------------------------------------------------------------------------
# Test 10: Read cycle counter
#-----------------------------------------------------------------------------
test_10:
    csrr    t0, cycle           # Read cycle
    nop
    nop
    nop
    csrr    t1, cycle           # Read again
    # t1 should be greater than t0
    bleu    t1, t0, test_fail_trap
    li      x30, 10

#-----------------------------------------------------------------------------
# All tests passed
#-----------------------------------------------------------------------------
test_pass_trap:
    li      t0, TOHOST
    li      t1, TEST_PASS
    sw      t1, 0(t0)
    j       test_done_trap

test_fail_trap:
    li      t0, TOHOST
    slli    t1, x30, 1          # Test number << 1 (LSB=0 means fail)
    sw      t1, 0(t0)

test_done_trap:
    j       test_done_trap
