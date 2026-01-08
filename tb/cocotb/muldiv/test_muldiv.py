import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Operations
MD_MUL    = 0
MD_MULH   = 1
MD_MULHSU = 2
MD_MULHU  = 3
MD_DIV    = 4
MD_DIVU   = 5
MD_REM    = 6
MD_REMU   = 7

async def reset_dut(dut):
    dut.rst_ni.value = 0
    dut.start_i.value = 0
    dut.op_i.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    await Timer(20, units='ns')
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

async def drive_muldiv(dut, op, a, b):
    dut.op_i.value = op
    dut.a_i.value = a
    dut.b_i.value = b
    dut.start_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.start_i.value = 0
    
    # Wait for valid_o
    timeout = 100
    while dut.valid_o.value == 0:
        await RisingEdge(dut.clk_i)
        timeout -= 1
        if timeout == 0:
            raise TestFailure("Timeout waiting for muldiv valid_o")
            
    return dut.result_o.value

def to_signed(val):
    val = int(val)
    if val > 0x7FFFFFFF:
        return val - 0x100000000
    return val

@cocotb.test()
async def test_muldiv_basic(dut):
    """Basic multiplication and division verification"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # Simple MUL
    res = await drive_muldiv(dut, MD_MUL, 10, 20)
    assert res == 200, f"Expected 200, got {res}"
    
    # Simple DIV
    res = await drive_muldiv(dut, MD_DIV, 200, 10)
    assert res == 20, f"Expected 20, got {res}"

@cocotb.test()
async def test_muldiv_divide_by_zero(dut):
    """Test Division by Zero (Corner Case)"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # DIV by 0 -> -1 (0xFFFFFFFF)
    res = await drive_muldiv(dut, MD_DIV, 100, 0)
    assert res == 0xFFFFFFFF, f"DIV by 0: Expected -1, got {res}"
    
    # DIVU by 0 -> Max Int
    res = await drive_muldiv(dut, MD_DIVU, 100, 0)
    assert res == 0xFFFFFFFF, f"DIVU by 0: Expected Max, got {res}"
    
    # REM by 0 -> Dividend
    res = await drive_muldiv(dut, MD_REM, 100, 0)
    assert res == 100, f"REM by 0: Expected 100, got {res}"

@cocotb.test()
async def test_muldiv_overflow(dut):
    """Test Overflow Case (MIN_INT / -1)"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # MIN_INT / -1 -> MIN_INT (Overflow)
    min_int = 0x80000000
    minus_one = 0xFFFFFFFF
    
    res = await drive_muldiv(dut, MD_DIV, min_int, minus_one)
    assert res == 0x80000000, f"Overflow DIV: Expected MIN_INT, got {res}"
    
    res = await drive_muldiv(dut, MD_REM, min_int, minus_one)
    assert res == 0, f"Overflow REM: Expected 0, got {res}"

@cocotb.test()
async def test_muldiv_mixed_signs(dut):
    """Test Signed/Unsigned Mixed Operations"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # -10 / 2 = -5
    res = await drive_muldiv(dut, MD_DIV, 0xFFFFFFF6, 2)
    dut._log.info(f"-10/2: Got {hex(res)} ({to_signed(res)})")
    assert to_signed(res) == -5, f"-10/2: Expected -5, got {to_signed(res)}"
    
    # 10 / -2 = -5
    res = await drive_muldiv(dut, MD_DIV, 10, 0xFFFFFFFE)
    dut._log.info(f"10/-2: Got {hex(res)} ({to_signed(res)})")
    assert to_signed(res) == -5, f"10/-2: Expected -5, got {to_signed(res)}"
    
    # -10 / -2 = 5
    res = await drive_muldiv(dut, MD_DIV, 0xFFFFFFF6, 0xFFFFFFFE)
    dut._log.info(f"-10/-2: Got {hex(res)} ({to_signed(res)})")
    assert res == 5, f"-10/-2: Expected 5, got {to_signed(res)}"

@cocotb.test()
async def test_muldiv_random(dut):
    """Randomized Soak Test"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    for _ in range(50):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(1, 0xFFFFFFFF) # Avoid 0 here to check normal logic
        
        # MUL
        await drive_muldiv(dut, MD_MUL, a, b)
        
        # DIV
        await drive_muldiv(dut, MD_DIVU, a, b)
