# IronCore Branch Tests
# Verifies all branch types and prediction behavior

#include "test_macros.h"

RVTEST_CODE_BEGIN

#-----------------------------------------------------------------------------
# Test 1: BEQ taken
#-----------------------------------------------------------------------------
test_1:
    li      x1, 5
    li      x2, 5
    beq     x1, x2, test_1_pass
    j       test_fail
test_1_pass:
    li      x30, 1

#-----------------------------------------------------------------------------
# Test 2: BEQ not taken
#-----------------------------------------------------------------------------
test_2:
    li      x1, 5
    li      x2, 6
    beq     x1, x2, test_fail
    li      x30, 2

#-----------------------------------------------------------------------------
# Test 3: BNE taken
#-----------------------------------------------------------------------------
test_3:
    li      x1, 5
    li      x2, 6
    bne     x1, x2, test_3_pass
    j       test_fail
test_3_pass:
    li      x30, 3

#-----------------------------------------------------------------------------
# Test 4: BNE not taken
#-----------------------------------------------------------------------------
test_4:
    li      x1, 7
    li      x2, 7
    bne     x1, x2, test_fail
    li      x30, 4

#-----------------------------------------------------------------------------
# Test 5: BLT taken (signed less than)
#-----------------------------------------------------------------------------
test_5:
    li      x1, -5
    li      x2, 5
    blt     x1, x2, test_5_pass
    j       test_fail
test_5_pass:
    li      x30, 5

#-----------------------------------------------------------------------------
# Test 6: BLT not taken
#-----------------------------------------------------------------------------
test_6:
    li      x1, 10
    li      x2, 5
    blt     x1, x2, test_fail
    li      x30, 6

#-----------------------------------------------------------------------------
# Test 7: BGE taken (signed greater or equal)
#-----------------------------------------------------------------------------
test_7:
    li      x1, 5
    li      x2, 5
    bge     x1, x2, test_7_pass
    j       test_fail
test_7_pass:
    li      x30, 7

#-----------------------------------------------------------------------------
# Test 8: BGE with greater
#-----------------------------------------------------------------------------
test_8:
    li      x1, 10
    li      x2, 5
    bge     x1, x2, test_8_pass
    j       test_fail
test_8_pass:
    li      x30, 8

#-----------------------------------------------------------------------------
# Test 9: BLTU taken (unsigned less than)
#-----------------------------------------------------------------------------
test_9:
    li      x1, 5
    li      x2, 0xFFFFFFFF      # Max unsigned
    bltu    x1, x2, test_9_pass
    j       test_fail
test_9_pass:
    li      x30, 9

#-----------------------------------------------------------------------------
# Test 10: BLTU not taken (unsigned compare, -1 is large!)
#-----------------------------------------------------------------------------
test_10:
    li      x1, 0xFFFFFFFF      # Max unsigned
    li      x2, 5
    bltu    x1, x2, test_fail   # 0xFFFFFFFF > 5 unsigned
    li      x30, 10

#-----------------------------------------------------------------------------
# Test 11: BGEU taken
#-----------------------------------------------------------------------------
test_11:
    li      x1, 0xFFFFFFFF
    li      x2, 5
    bgeu    x1, x2, test_11_pass
    j       test_fail
test_11_pass:
    li      x30, 11

#-----------------------------------------------------------------------------
# Test 12: BGEU equal
#-----------------------------------------------------------------------------
test_12:
    li      x1, 100
    li      x2, 100
    bgeu    x1, x2, test_12_pass
    j       test_fail
test_12_pass:
    li      x30, 12

#-----------------------------------------------------------------------------
# Test 13: Forward branch (positive offset)
#-----------------------------------------------------------------------------
test_13:
    li      x1, 1
    beq     x1, x1, test_13_forward
    j       test_fail
    j       test_fail
    j       test_fail
test_13_forward:
    li      x30, 13

#-----------------------------------------------------------------------------
# Test 14: Backward branch (loop)
#-----------------------------------------------------------------------------
test_14:
    li      x1, 3               # Counter
    li      x2, 0               # Accumulator
test_14_loop:
    addi    x2, x2, 1           # acc++
    addi    x1, x1, -1          # counter--
    bne     x1, x0, test_14_loop
    # x2 should be 3
    TEST_CASE 14, x2, 3

#-----------------------------------------------------------------------------
# Test 15: Branch delay slot correctness
# Instruction after branch should NOT execute if branch taken
#-----------------------------------------------------------------------------
test_15:
    li      x1, 1
    li      x3, 0               # Should stay 0
    beq     x1, x1, test_15_pass
    addi    x3, x3, 1           # Should NOT execute (flushed)
test_15_pass:
    TEST_CASE 15, x3, 0

#-----------------------------------------------------------------------------
# Test 16: Multiple consecutive branches
#-----------------------------------------------------------------------------
test_16:
    li      x1, 10
    li      x2, 10
    li      x3, 20
    beq     x1, x2, test_16_a   # Taken
    j       test_fail
test_16_a:
    bne     x1, x3, test_16_b   # Taken
    j       test_fail
test_16_b:
    blt     x1, x3, test_16_pass # Taken
    j       test_fail
test_16_pass:
    li      x30, 16

RVTEST_CODE_END
