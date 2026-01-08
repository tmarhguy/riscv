# IronCore Test Macros
# Common macros for assembly verification tests

# Memory-mapped test interface
.equ TOHOST,     0x80001000   # Write test result here
.equ FROMHOST,   0x80001004   # Host can write commands here

# Test result codes
.equ TEST_PASS,  0x00000001
.equ TEST_FAIL,  0x00000000

#-----------------------------------------------------------------------------
# TEST_INIT - Initialize test environment
#-----------------------------------------------------------------------------
.macro TEST_INIT
    .section .text.init
    .global _start
_start:
    # Set up stack
    la      sp, _stack_top
    # Clear registers
    li      x1, 0
    li      x2, 0
    li      x3, 0
    li      x4, 0
    li      x5, 0
    li      x6, 0
    li      x7, 0
    li      x8, 0
    li      x9, 0
    li      x10, 0
    li      x11, 0
    li      x12, 0
    li      x13, 0
    li      x14, 0
    li      x15, 0
    # Jump to test code
    j       test_start
.endm

#-----------------------------------------------------------------------------
# TEST_CASE - Define a test case
# Arguments: test_num, register, expected_value
#-----------------------------------------------------------------------------
.macro TEST_CASE test_num, reg, expected
    li      x30, \test_num          # Test number in x30
    li      x31, \expected          # Expected value in x31
    bne     \reg, x31, test_fail    # Compare and branch if fail
.endm

#-----------------------------------------------------------------------------
# TEST_PASS_MACRO - Signal test passed
#-----------------------------------------------------------------------------
.macro TEST_PASS_MACRO
    li      t0, TOHOST
    li      t1, TEST_PASS
    sw      t1, 0(t0)
    j       test_done
.endm

#-----------------------------------------------------------------------------
# TEST_FAIL_MACRO - Signal test failed (x30 = test number)
#-----------------------------------------------------------------------------
.macro TEST_FAIL_MACRO
test_fail:
    li      t0, TOHOST
    # Store test number that failed (shifted left by 1, LSB=0 means fail)
    slli    t1, x30, 1
    sw      t1, 0(t0)
    j       test_done
.endm

#-----------------------------------------------------------------------------
# TEST_END - End of test, infinite loop
#-----------------------------------------------------------------------------
.macro TEST_END
test_done:
    j       test_done
.endm

#-----------------------------------------------------------------------------
# RVTEST_CODE_BEGIN / RVTEST_CODE_END - Compatibility macros
#-----------------------------------------------------------------------------
.macro RVTEST_CODE_BEGIN
    TEST_INIT
test_start:
.endm

.macro RVTEST_CODE_END
    TEST_PASS_MACRO
    TEST_FAIL_MACRO
    TEST_END
.endm
