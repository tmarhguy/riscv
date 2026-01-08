# IronCore Load/Store Tests
# Verifies all memory access widths and alignments

#include "test_macros.h"

RVTEST_CODE_BEGIN

    # Base address for tests
    li      x20, 0x80000200

#-----------------------------------------------------------------------------
# Test 1: SW/LW (word)
#-----------------------------------------------------------------------------
test_1:
    li      x1, 0xDEADBEEF
    sw      x1, 0(x20)
    nop
    nop
    lw      x2, 0(x20)
    TEST_CASE 1, x2, 0xDEADBEEF

#-----------------------------------------------------------------------------
# Test 2: SH/LH (halfword, signed)
#-----------------------------------------------------------------------------
test_2:
    li      x1, 0xFFFF8000      # -32768 in lower half
    sw      x1, 4(x20)          # Store full word first
    nop
    nop
    lh      x2, 4(x20)          # Load signed halfword
    li      x3, 0xFFFF8000      # Expected: sign-extended
    beq     x2, x3, test_2_pass
    j       test_fail
test_2_pass:
    li      x30, 2

#-----------------------------------------------------------------------------
# Test 3: SH/LHU (halfword, unsigned)
#-----------------------------------------------------------------------------
test_3:
    li      x1, 0x00008000      # 32768 in lower half
    sw      x1, 8(x20)
    nop
    nop
    lhu     x2, 8(x20)          # Load unsigned halfword
    li      x3, 0x00008000      # Expected: zero-extended
    beq     x2, x3, test_3_pass
    j       test_fail
test_3_pass:
    li      x30, 3

#-----------------------------------------------------------------------------
# Test 4: SB/LB (byte, signed)
#-----------------------------------------------------------------------------
test_4:
    li      x1, 0x00000080      # -128 as byte
    sw      x1, 12(x20)
    nop
    nop
    lb      x2, 12(x20)         # Load signed byte
    li      x3, 0xFFFFFF80      # Expected: sign-extended
    beq     x2, x3, test_4_pass
    j       test_fail
test_4_pass:
    li      x30, 4

#-----------------------------------------------------------------------------
# Test 5: SB/LBU (byte, unsigned)
#-----------------------------------------------------------------------------
test_5:
    li      x1, 0x000000FF      # 255 as byte
    sw      x1, 16(x20)
    nop
    nop
    lbu     x2, 16(x20)         # Load unsigned byte
    li      x3, 0x000000FF      # Expected: zero-extended
    beq     x2, x3, test_5_pass
    j       test_fail
test_5_pass:
    li      x30, 5

#-----------------------------------------------------------------------------
# Test 6: Store halfword to offset 0
#-----------------------------------------------------------------------------
test_6:
    li      x1, 0x12345678
    sw      x1, 20(x20)         # Store known pattern
    li      x2, 0xABCD
    sh      x2, 20(x20)         # Overwrite lower halfword
    nop
    nop
    lw      x3, 20(x20)
    li      x4, 0x1234ABCD      # Upper preserved, lower changed
    beq     x3, x4, test_6_pass
    j       test_fail
test_6_pass:
    li      x30, 6

#-----------------------------------------------------------------------------
# Test 7: Store halfword to offset 2
#-----------------------------------------------------------------------------
test_7:
    li      x1, 0x12345678
    sw      x1, 24(x20)         # Store known pattern
    li      x2, 0xABCD
    sh      x2, 26(x20)         # Overwrite upper halfword (offset 2)
    nop
    nop
    lw      x3, 24(x20)
    li      x4, 0xABCD5678      # Upper changed, lower preserved
    beq     x3, x4, test_7_pass
    j       test_fail
test_7_pass:
    li      x30, 7

#-----------------------------------------------------------------------------
# Test 8: Store byte to each offset
#-----------------------------------------------------------------------------
test_8:
    li      x1, 0x00000000
    sw      x1, 28(x20)         # Clear word

    li      x2, 0x11
    sb      x2, 28(x20)         # Byte 0
    li      x2, 0x22
    sb      x2, 29(x20)         # Byte 1
    li      x2, 0x33
    sb      x2, 30(x20)         # Byte 2
    li      x2, 0x44
    sb      x2, 31(x20)         # Byte 3

    nop
    nop
    lw      x3, 28(x20)
    li      x4, 0x44332211      # Little-endian: 0x11 at lowest addr
    beq     x3, x4, test_8_pass
    j       test_fail
test_8_pass:
    li      x30, 8

#-----------------------------------------------------------------------------
# Test 9: Load byte from each offset
#-----------------------------------------------------------------------------
test_9:
    li      x1, 0xAABBCCDD
    sw      x1, 32(x20)
    nop
    nop

    lbu     x2, 32(x20)         # Should be 0xDD (byte 0)
    li      x3, 0xDD
    bne     x2, x3, test_fail

    lbu     x2, 33(x20)         # Should be 0xCC (byte 1)
    li      x3, 0xCC
    bne     x2, x3, test_fail

    lbu     x2, 34(x20)         # Should be 0xBB (byte 2)
    li      x3, 0xBB
    bne     x2, x3, test_fail

    lbu     x2, 35(x20)         # Should be 0xAA (byte 3)
    li      x3, 0xAA
    bne     x2, x3, test_fail

    li      x30, 9

#-----------------------------------------------------------------------------
# Test 10: Load halfword from offset 0 and 2
#-----------------------------------------------------------------------------
test_10:
    li      x1, 0x12345678
    sw      x1, 36(x20)
    nop
    nop

    lhu     x2, 36(x20)         # Lower half: 0x5678
    li      x3, 0x5678
    bne     x2, x3, test_fail

    lhu     x2, 38(x20)         # Upper half: 0x1234
    li      x3, 0x1234
    bne     x2, x3, test_fail

    li      x30, 10

#-----------------------------------------------------------------------------
# Test 11: Negative offset
#-----------------------------------------------------------------------------
test_11:
    li      x1, 0x80000300      # Higher address
    li      x2, 0xCAFEBABE
    sw      x2, 0(x1)
    nop
    nop
    lw      x3, -256(x1)        # Load from 0x80000200 (test_1's location)
    li      x4, 0xDEADBEEF      # This was stored in test_1
    beq     x3, x4, test_11_pass
    j       test_fail
test_11_pass:
    li      x30, 11

#-----------------------------------------------------------------------------
# Test 12: Back-to-back loads
#-----------------------------------------------------------------------------
test_12:
    li      x1, 0x11111111
    li      x2, 0x22222222
    li      x3, 0x33333333
    sw      x1, 40(x20)
    sw      x2, 44(x20)
    sw      x3, 48(x20)
    nop
    nop

    lw      x4, 40(x20)
    lw      x5, 44(x20)
    lw      x6, 48(x20)

    add     x7, x4, x5
    add     x7, x7, x6          # x7 = 0x11111111 + 0x22222222 + 0x33333333
    li      x8, 0x66666666
    beq     x7, x8, test_12_pass
    j       test_fail
test_12_pass:
    li      x30, 12

#-----------------------------------------------------------------------------
# Test 13: Back-to-back stores
#-----------------------------------------------------------------------------
test_13:
    li      x1, 0xAAAAAAAA
    li      x2, 0xBBBBBBBB
    sw      x1, 52(x20)
    sw      x2, 56(x20)
    nop
    nop
    lw      x3, 52(x20)
    lw      x4, 56(x20)
    bne     x3, x1, test_fail
    bne     x4, x2, test_fail
    li      x30, 13

RVTEST_CODE_END
