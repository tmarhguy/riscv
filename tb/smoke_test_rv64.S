# RV64IM Smoke Test
# Tests basic 64-bit operations, word operations, and memory access

.section .text
.globl _start

_start:
    # Test 1: 64-bit ADD/SUB
    li      x1, 0x0000000100000000      # Load large 64-bit value
    li      x2, 0x0000000200000000
    add     x3, x1, x2                  # x3 = 0x300000000
    sub     x4, x3, x1                  # x4 = 0x200000000
    
    # Test 2: Word operations (ADDW with sign-extension)
    li      x5, 0x7FFFFFFF              # Max positive 32-bit
    li      x6, 1
    addw    x7, x5, x6                  # x7 = 0xFFFFFFFF80000000 (sign-extended)
    
    # Test 3: SUBW
    li      x8, 0x0000000080000000      # -2^31 in lower 32 bits
    li      x9, 1
    subw    x10, x8, x9                 # x10 = 0x000000007FFFFFFF (sign-extended)
    
    # Test 4: 64-bit shifts
    li      x11, 1
    slli    x12, x11, 40                # x12 = 0x10000000000 (shift by 40)
    srli    x13, x12, 20                # x13 = 0x100000 (shift right by 20)
    
    # Test 5: Word shifts (SLLIW, SRLIW)
    li      x14, 0xFFFFFFFF12345678
    slliw   x15, x14, 4                 # x15 = 0x0000000023456780 (sign-extended)
    srliw   x16, x14, 4                 # x16 = 0x0000000001234567 (zero-extended upper)
    
    # Test 6: Load/Store Doubleword (LD/SD)
    la      x17, test_data
    ld      x18, 0(x17)                 # Load 64-bit value
    sd      x18, 8(x17)                 # Store to next location
    
    # Test 7: Load Word Unsigned (LWU)
    li      x19, 0xFFFFFFFF
    la      x20, test_data
    sw      x19, 16(x20)                # Store 0xFFFFFFFF
    lwu     x21, 16(x20)                # Load as unsigned: x21 = 0x00000000FFFFFFFF
    
    # Test 8: Comparison (64-bit)
    li      x22, 0x8000000000000000     # Most negative 64-bit
    li      x23, 0x7FFFFFFFFFFFFFFF     # Most positive 64-bit
    slt     x24, x22, x23               # x24 = 1 (signed comparison)
    sltu    x25, x22, x23               # x25 = 0 (unsigned: 0x8... > 0x7...)
    
    # Test 9: JAL/JALR (64-bit PC)
    jal     x26, test_jal
    nop
    
test_jal:
    # x26 should contain return address
    la      x27, test_jalr_target
    jalr    x28, x27, 0
    nop
    
test_jalr_target:
    # x28 should contain return address
    
    # Success: Write magic value to indicate test passed
    li      x29, 0xDEADBEEFCAFEBABE
    la      x30, result
    sd      x29, 0(x30)
    
    # End test (infinite loop)
end:
    j       end

.section .data
.align 3
test_data:
    .dword  0x123456789ABCDEF0
    .dword  0x0000000000000000
    .dword  0x0000000000000000

result:
    .dword  0x0000000000000000
