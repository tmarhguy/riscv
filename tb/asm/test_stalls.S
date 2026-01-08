# IronCore Stall Tests
# Verifies load-use stalls and pipeline control

#include "test_macros.h"

RVTEST_CODE_BEGIN

#-----------------------------------------------------------------------------
# Test 1: Load-use hazard (must stall 1 cycle)
# Store value, load it, use immediately
#-----------------------------------------------------------------------------
test_1:
    li      x1, 0x80000100      # RAM address
    li      x2, 42              # Value to store
    sw      x2, 0(x1)           # Store 42
    nop
    nop
    lw      x3, 0(x1)           # Load 42
    addi    x4, x3, 8           # Use immediately - needs stall!
    TEST_CASE 1, x4, 50

#-----------------------------------------------------------------------------
# Test 2: Load followed by independent instruction (no stall needed)
#-----------------------------------------------------------------------------
test_2:
    li      x1, 0x80000104
    li      x2, 100
    sw      x2, 0(x1)
    nop
    nop
    lw      x3, 0(x1)           # Load 100
    li      x5, 200             # Independent - no stall
    add     x4, x3, x0          # Use after 1 cycle - still needs stall
    TEST_CASE 2, x4, 100

#-----------------------------------------------------------------------------
# Test 3: Load with 1 NOP gap (should not need stall)
#-----------------------------------------------------------------------------
test_3:
    li      x1, 0x80000108
    li      x2, 77
    sw      x2, 0(x1)
    nop
    nop
    lw      x3, 0(x1)           # Load 77
    nop                         # 1 cycle gap
    addi    x4, x3, 3           # Should be forwarded, no stall
    TEST_CASE 3, x4, 80

#-----------------------------------------------------------------------------
# Test 4: Double load-use (consecutive loads used immediately)
#-----------------------------------------------------------------------------
test_4:
    li      x1, 0x80000110
    li      x2, 10
    li      x3, 20
    sw      x2, 0(x1)
    sw      x3, 4(x1)
    nop
    nop
    lw      x4, 0(x1)           # Load 10
    lw      x5, 4(x1)           # Load 20
    add     x6, x4, x5          # Use both - complex stall scenario
    TEST_CASE 4, x6, 30

#-----------------------------------------------------------------------------
# Test 5: Load-use with branch
#-----------------------------------------------------------------------------
test_5:
    li      x1, 0x80000120
    li      x2, 5
    sw      x2, 0(x1)
    nop
    nop
    lw      x3, 0(x1)           # Load 5
    li      x4, 5
    beq     x3, x4, test_5_pass # Branch uses loaded value - stall!
    j       test_fail
test_5_pass:
    li      x30, 5

#-----------------------------------------------------------------------------
# Test 6: Store after load (no hazard, just verify correctness)
#-----------------------------------------------------------------------------
test_6:
    li      x1, 0x80000130
    li      x2, 99
    sw      x2, 0(x1)
    nop
    nop
    lw      x3, 0(x1)           # Load 99
    sw      x3, 4(x1)           # Store loaded value (needs forward, stall)
    nop
    nop
    lw      x4, 4(x1)           # Verify store worked
    TEST_CASE 6, x4, 99

#-----------------------------------------------------------------------------
# Test 7: Load byte, use immediately
#-----------------------------------------------------------------------------
test_7:
    li      x1, 0x80000140
    li      x2, 0x12345678
    sw      x2, 0(x1)
    nop
    nop
    lb      x3, 0(x1)           # Load byte (0x78, sign-extended)
    addi    x4, x3, 0           # Use immediately
    li      x5, 0x78
    bne     x4, x5, test_fail
    li      x30, 7

#-----------------------------------------------------------------------------
# Test 8: Load halfword, use immediately
#-----------------------------------------------------------------------------
test_8:
    li      x1, 0x80000150
    li      x2, 0xABCD1234
    sw      x2, 0(x1)
    nop
    nop
    lhu     x3, 0(x1)           # Load halfword unsigned (0x1234)
    addi    x4, x3, 0           # Use immediately
    li      x5, 0x1234
    bne     x4, x5, test_fail
    li      x30, 8

RVTEST_CODE_END
