# IronCore Forwarding Tests
# Verifies RAW hazard forwarding paths work correctly

#include "test_macros.h"

RVTEST_CODE_BEGIN

#-----------------------------------------------------------------------------
# Test 1: EX→EX forwarding (result needed immediately)
# add x2, x1, x0 ; x2 = 10
# add x3, x2, x0 ; x3 = 10 (forward from EX/MEM to EX)
#-----------------------------------------------------------------------------
test_1:
    li      x1, 10
    add     x2, x1, x0      # x2 = 10
    add     x3, x2, x0      # x3 should be 10 (forwarded)
    TEST_CASE 1, x3, 10

#-----------------------------------------------------------------------------
# Test 2: MEM→EX forwarding (result needed after 1 cycle)
# add x2, x1, x0 ; x2 = 20
# nop
# add x3, x2, x0 ; x3 = 20 (forward from MEM/WB to EX)
#-----------------------------------------------------------------------------
test_2:
    li      x1, 20
    add     x2, x1, x0      # x2 = 20
    nop                     # 1 cycle gap
    add     x3, x2, x0      # x3 should be 20 (forwarded from WB)
    TEST_CASE 2, x3, 20

#-----------------------------------------------------------------------------
# Test 3: Double forwarding (both operands forwarded)
# li x1, 5
# li x2, 7
# add x3, x1, x2 ; both x1 and x2 need forwarding
#-----------------------------------------------------------------------------
test_3:
    li      x1, 5           # x1 = 5
    li      x2, 7           # x2 = 7
    add     x3, x1, x2      # x3 = 12 (both forwarded)
    TEST_CASE 3, x3, 12

#-----------------------------------------------------------------------------
# Test 4: Chain of dependent instructions
# addi x1, x0, 1
# addi x2, x1, 1
# addi x3, x2, 1
# addi x4, x3, 1
#-----------------------------------------------------------------------------
test_4:
    addi    x1, x0, 1       # x1 = 1
    addi    x2, x1, 1       # x2 = 2 (forward)
    addi    x3, x2, 1       # x3 = 3 (forward)
    addi    x4, x3, 1       # x4 = 4 (forward)
    TEST_CASE 4, x4, 4

#-----------------------------------------------------------------------------
# Test 5: Forwarding with different ALU ops
# sub, and, or, xor
#-----------------------------------------------------------------------------
test_5:
    li      x1, 100
    li      x2, 30
    sub     x3, x1, x2      # x3 = 70
    addi    x4, x3, 5       # x4 = 75 (forward from sub)
    TEST_CASE 5, x4, 75

test_6:
    li      x1, 0xFF
    li      x2, 0x0F
    and     x3, x1, x2      # x3 = 0x0F
    addi    x4, x3, 1       # x4 = 0x10 (forward from and)
    TEST_CASE 6, x4, 0x10

test_7:
    li      x1, 0xF0
    li      x2, 0x0F
    or      x3, x1, x2      # x3 = 0xFF
    addi    x4, x3, 1       # x4 = 0x100 (forward from or)
    TEST_CASE 7, x4, 0x100

#-----------------------------------------------------------------------------
# Test 8: Forwarding to both operands of branch comparison
#-----------------------------------------------------------------------------
test_8:
    li      x1, 42
    li      x2, 42
    beq     x1, x2, test_8_pass  # Both operands forwarded
    j       test_fail
test_8_pass:
    li      x30, 8              # Mark test 8
    # Continue to next test

#-----------------------------------------------------------------------------
# Test 9: No forwarding needed (x0 source)
#-----------------------------------------------------------------------------
test_9:
    addi    x1, x0, 99      # x0 always 0, no forwarding
    TEST_CASE 9, x1, 99

#-----------------------------------------------------------------------------
# Test 10: Write then read x0 (should stay 0)
#-----------------------------------------------------------------------------
test_10:
    addi    x0, x0, 100     # Write to x0 (should be ignored)
    add     x1, x0, x0      # x1 = 0 (x0 is always 0)
    TEST_CASE 10, x1, 0

RVTEST_CODE_END
