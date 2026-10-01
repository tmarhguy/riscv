import cocotb
from cocotb.triggers import Timer
import random

# ALU Operations from rv64xo3_pkg.sv (5-bit; low 4 bits match legacy 4-bit tests)
ALU_ADD    = 0b00000
ALU_SUB    = 0b00001
ALU_SLL    = 0b00010
ALU_SLT    = 0b00011
ALU_SLTU   = 0b00100
ALU_XOR    = 0b00101
ALU_SRL    = 0b00110
ALU_SRA    = 0b00111
ALU_OR     = 0b01000
ALU_AND    = 0b01001
ALU_PASS_B = 0b01010
ALU_ADDW   = 0b01011
ALU_SUBW   = 0b01100
ALU_SLLW   = 0b01101
ALU_SRLW   = 0b01110
ALU_SRAW   = 0b01111

MASK64 = 0xFFFFFFFFFFFFFFFF
MASK32 = 0xFFFFFFFF


def _sext32(v):
    v &= MASK32
    return v - 0x100000000 if v & 0x80000000 else v


def model_alu(op, a, b):
    # RV64 model: 64-bit operands, 6-bit shift amounts, W-ops sign-extended
    a &= MASK64
    b &= MASK64

    res = 0
    if op == ALU_ADD:
        res = (a + b) & MASK64
    elif op == ALU_SUB:
        res = (a - b) & MASK64
    elif op == ALU_SLL:
        res = (a << (b & 0x3F)) & MASK64
    elif op == ALU_SLT:
        a_s = a if a < 0x8000000000000000 else a - 0x10000000000000000
        b_s = b if b < 0x8000000000000000 else b - 0x10000000000000000
        res = 1 if a_s < b_s else 0
    elif op == ALU_SLTU:
        res = 1 if a < b else 0
    elif op == ALU_XOR:
        res = a ^ b
    elif op == ALU_SRL:
        res = a >> (b & 0x3F)
    elif op == ALU_SRA:
        a_s = a if a < 0x8000000000000000 else a - 0x10000000000000000
        res = (a_s >> (b & 0x3F)) & MASK64
    elif op == ALU_OR:
        res = a | b
    elif op == ALU_AND:
        res = a & b
    elif op == ALU_PASS_B:
        res = b
    elif op == ALU_ADDW:
        w = ((a & MASK32) + (b & MASK32)) & MASK32
        res = (w - 0x100000000 if w & 0x80000000 else w) & MASK64
    elif op == ALU_SUBW:
        w = ((a & MASK32) - (b & MASK32)) & MASK32
        res = (w - 0x100000000 if w & 0x80000000 else w) & MASK64
    elif op == ALU_SLLW:
        w = ((a & MASK32) << (b & 0x1F)) & MASK32
        res = (w - 0x100000000 if w & 0x80000000 else w) & MASK64
    elif op == ALU_SRLW:
        w = (a & MASK32) >> (b & 0x1F)
        res = (w - 0x100000000 if w & 0x80000000 else w) & MASK64
    elif op == ALU_SRAW:
        res = (_sext32(a) >> (b & 0x1F)) & MASK64

    return res

async def drive_alu(dut, op, a, b):
    dut.op_i.value = op
    dut.a_i.value = a
    dut.b_i.value = b
    await Timer(1, unit='ns')

    expected = model_alu(op, a, b)
    got = dut.result_o.value.integer

    if got != expected:
        assert False, (f"Op {op}: {a:#x} op {b:#x} = {got:#x}, expected {expected:#x}")

@cocotb.test()
async def test_alu_corner_cases(dut):
    """Test ALU corner cases (0, 1, -1, MAX, MIN)"""
    corner_values = [0, 1, MASK64, 0x8000000000000000, 0x7FFFFFFFFFFFFFFF,
                     0xAAAAAAAAAAAAAAAA, 0x5555555555555555, 0xFFFFFFFF, 0x80000000]
    ops = [
        ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
        ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_PASS_B,
        ALU_ADDW, ALU_SUBW, ALU_SLLW, ALU_SRLW, ALU_SRAW,
    ]

    for op in ops:
        for a in corner_values:
            for b in corner_values:
                await drive_alu(dut, op, a, b)

@cocotb.test()
async def test_alu_shifts_full_range(dut):
    """Test all shift amounts 0-63 with various patterns"""
    shift_ops = [ALU_SLL, ALU_SRL, ALU_SRA]
    patterns = [MASK64, 0x8000000000000000, 0x1, 0xAAAAAAAAAAAAAAAA, 0x5555555555555555]

    for op in shift_ops:
        for a in patterns:
            for shamt in range(64):
                await drive_alu(dut, op, a, shamt)

@cocotb.test()
async def test_alu_bit_walking(dut):
    """Walking 1s and 0s to maximize toggle coverage"""
    ops = [ALU_OR, ALU_AND, ALU_XOR, ALU_ADD]

    for i in range(64):
        val = 1 << i
        for op in ops:
            await drive_alu(dut, op, val, 0)
            await drive_alu(dut, op, 0, val)
            await drive_alu(dut, op, val, MASK64)

@cocotb.test()
async def test_alu_random_intensive(dut):
    """Intensive randomized testing"""
    for _ in range(2000):
        op = random.randint(0, 15)  # all 64-bit + W ops
        a = random.randint(0, MASK64)
        b = random.randint(0, MASK64)
        await drive_alu(dut, op, a, b)
