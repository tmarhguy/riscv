# IronCore Jump Tests
# Verifies JAL and JALR instructions

#include "test_macros.h"

RVTEST_CODE_BEGIN

#-----------------------------------------------------------------------------
# Test 1: JAL forward, verify link address
#-----------------------------------------------------------------------------
test_1:
    jal     x1, test_1_target   # x1 = PC + 4
test_1_return:
    # x1 should contain address of test_1_return
    la      x2, test_1_return
    beq     x1, x2, test_1_pass
    j       test_fail
test_1_target:
    j       test_1_return
test_1_pass:
    li      x30, 1

#-----------------------------------------------------------------------------
# Test 2: JAL with x0 (no link)
#-----------------------------------------------------------------------------
test_2:
    li      x1, 0xDEADBEEF      # Canary value
    jal     x0, test_2_target   # Link to x0 (discarded)
    j       test_fail
test_2_target:
    # x1 should still be canary (x0 wasn't written)
    li      x2, 0xDEADBEEF
    beq     x1, x2, test_2_pass
    j       test_fail
test_2_pass:
    li      x30, 2

#-----------------------------------------------------------------------------
# Test 3: JALR (indirect jump)
#-----------------------------------------------------------------------------
test_3:
    la      x2, test_3_target   # Load target address
    jalr    x1, x2, 0           # Jump to x2, link in x1
test_3_return:
    la      x3, test_3_return
    beq     x1, x3, test_3_pass
    j       test_fail
test_3_target:
    j       test_3_return
test_3_pass:
    li      x30, 3

#-----------------------------------------------------------------------------
# Test 4: JALR with offset
#-----------------------------------------------------------------------------
test_4:
    la      x2, test_4_base
    jalr    x1, x2, 8           # Jump to test_4_base + 8
test_4_return:
    la      x3, test_4_return
    beq     x1, x3, test_4_pass
    j       test_fail
test_4_base:
    j       test_fail           # +0: should skip
    j       test_fail           # +4: should skip
    j       test_4_return       # +8: should hit this
test_4_pass:
    li      x30, 4

#-----------------------------------------------------------------------------
# Test 5: Function call and return pattern
#-----------------------------------------------------------------------------
test_5:
    li      x10, 5              # Argument
    jal     x1, add_ten         # Call function
    # x10 should now be 15
    TEST_CASE 5, x10, 15
    j       test_6

# Simple function: adds 10 to x10
add_ten:
    addi    x10, x10, 10
    jalr    x0, x1, 0           # Return (jr ra)

#-----------------------------------------------------------------------------
# Test 6: Nested function calls
#-----------------------------------------------------------------------------
test_6:
    li      x10, 1              # Start value
    jal     x1, outer_func
    # x10 should be ((1+5)*2) = 12
    TEST_CASE 6, x10, 12
    j       test_7

outer_func:
    addi    sp, sp, -4
    sw      x1, 0(sp)           # Save return address
    addi    x10, x10, 5         # x10 = 6
    jal     x1, inner_func      # Call inner
    lw      x1, 0(sp)           # Restore return address
    addi    sp, sp, 4
    jalr    x0, x1, 0           # Return

inner_func:
    slli    x10, x10, 1         # x10 *= 2
    jalr    x0, x1, 0           # Return

#-----------------------------------------------------------------------------
# Test 7: JALR clears LSB (alignment)
#-----------------------------------------------------------------------------
test_7:
    la      x2, test_7_target
    addi    x2, x2, 1           # Make address odd
    jalr    x1, x2, 0           # Should clear LSB
test_7_fail:
    j       test_fail
test_7_target:
    li      x30, 7              # Success - we got here
    j       test_8

#-----------------------------------------------------------------------------
# Test 8: Jump table pattern
#-----------------------------------------------------------------------------
test_8:
    li      x10, 2              # Select case 2
    la      x11, jump_table
    slli    x12, x10, 2         # x12 = x10 * 4 (word offset)
    add     x11, x11, x12       # x11 = &jump_table[x10]
    lw      x11, 0(x11)         # x11 = jump_table[x10]
    jalr    x0, x11, 0          # Jump to case

jump_table:
    .word   case_0
    .word   case_1
    .word   case_2
    .word   case_3

case_0:
    li      x13, 100
    j       test_8_check
case_1:
    li      x13, 200
    j       test_8_check
case_2:
    li      x13, 300            # This should execute
    j       test_8_check
case_3:
    li      x13, 400
    j       test_8_check

test_8_check:
    TEST_CASE 8, x13, 300

#-----------------------------------------------------------------------------
# Test 9: Long jump (tests larger offsets)
#-----------------------------------------------------------------------------
test_9:
    jal     x1, test_9_far
test_9_return:
    TEST_CASE 9, x10, 0x12345678
    j       test_10

    # Padding to create distance
    .space  256

test_9_far:
    li      x10, 0x12345678
    jalr    x0, x1, 0

#-----------------------------------------------------------------------------
# Test 10: JALR to self (infinite loop escape)
#-----------------------------------------------------------------------------
test_10:
    li      x5, 3               # Counter
    la      x6, test_10_loop
test_10_loop:
    addi    x5, x5, -1
    beq     x5, x0, test_10_done
    jalr    x0, x6, 0           # Jump back to loop
test_10_done:
    TEST_CASE 10, x5, 0

RVTEST_CODE_END
