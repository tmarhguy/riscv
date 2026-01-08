import cocotb
from cocotb.triggers import Timer
import random
from cocotb.result import TestFailure

# ALU Operations from ironcore_pkg.sv
ALU_ADD    = 0b0000
ALU_SUB    = 0b0001
ALU_SLL    = 0b0010
ALU_SLT    = 0b0011
ALU_SLTU   = 0b0100
ALU_XOR    = 0b0101
ALU_SRL    = 0b0110
ALU_SRA    = 0b0111
ALU_OR     = 0b1000
ALU_AND    = 0b1001
ALU_PASS_B = 0b1010

def model_alu(op, a, b):
    # Mask to 32 bits
    a &= 0xFFFFFFFF
    b &= 0xFFFFFFFF
    
    res = 0
    if op == ALU_ADD:
        res = (a + b) & 0xFFFFFFFF
    elif op == ALU_SUB:
        res = (a - b) & 0xFFFFFFFF
    elif op == ALU_SLL:
        shamt = b & 0x1F
        res = (a << shamt) & 0xFFFFFFFF
    elif op == ALU_SLT:
        a_s = a if a < 0x80000000 else a - 0x100000000
        b_s = b if b < 0x80000000 else b - 0x100000000
        res = 1 if a_s < b_s else 0
    elif op == ALU_SLTU:
        res = 1 if a < b else 0
    elif op == ALU_XOR:
        res = a ^ b
    elif op == ALU_SRL:
        shamt = b & 0x1F
        res = a >> shamt
    elif op == ALU_SRA:
        shamt = b & 0x1F
        # Signed shift
        a_s = a if a < 0x80000000 else a - 0x100000000
        res_s = a_s >> shamt
        res = res_s & 0xFFFFFFFF
    elif op == ALU_OR:
        res = a | b
    elif op == ALU_AND:
        res = a & b
    elif op == ALU_PASS_B:
        res = b
    
    return res

async def drive_alu(dut, op, a, b):
    dut.op_i.value = op
    dut.a_i.value = a
    dut.b_i.value = b
    await Timer(1, units='ns')
    
    expected = model_alu(op, a, b)
    got = dut.result_o.value.integer
    
    if got != expected:
        raise TestFailure(f"Op {op}: {a:#x} op {b:#x} = {got:#x}, expected {expected:#x}")

@cocotb.test()
async def test_alu_corner_cases(dut):
    """Test ALU corner cases (0, 1, -1, MAX, MIN)"""
    corner_values = [0, 1, 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF, 0xAAAAAAAA, 0x55555555]
    ops = [
        ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, 
        ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_PASS_B
    ]
    
    for op in ops:
        for a in corner_values:
            for b in corner_values:
                await drive_alu(dut, op, a, b)

@cocotb.test()
async def test_alu_shifts_full_range(dut):
    """Test all shift amounts 0-31 with various patterns"""
    shift_ops = [ALU_SLL, ALU_SRL, ALU_SRA]
    patterns = [0xFFFFFFFF, 0x80000000, 0x1, 0xAAAAAAAA, 0x55555555]
    
    for op in shift_ops:
        for a in patterns:
            for shamt in range(32):
                await drive_alu(dut, op, a, shamt)

@cocotb.test()
async def test_alu_bit_walking(dut):
    """Walking 1s and 0s to maximize toggle coverage"""
    ops = [ALU_OR, ALU_AND, ALU_XOR, ALU_ADD]
    
    for i in range(32):
        val = 1 << i
        for op in ops:
            await drive_alu(dut, op, val, 0)
            await drive_alu(dut, op, 0, val)
            await drive_alu(dut, op, val, 0xFFFFFFFF)
            
@cocotb.test()
async def test_alu_random_intensive(dut):
    """Intensive randomized testing"""
    for _ in range(2000):
        op = random.randint(0, 10) # 0 to 10 inclusive, covering all ops defined
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        await drive_alu(dut, op, a, b)
