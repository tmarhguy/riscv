import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Operations (rv64xo3_pkg.sv muldiv_op_e)
MD_MUL    = 0
MD_MULH   = 1
MD_MULHSU = 2
MD_MULHU  = 3
MD_DIV    = 4
MD_DIVU   = 5
MD_REM    = 6
MD_REMU   = 7
MD_MULW   = 8
MD_DIVW   = 12
MD_DIVUW  = 13
MD_REMW   = 14
MD_REMUW  = 15

MASK64 = 0xFFFFFFFFFFFFFFFF
MASK32 = 0xFFFFFFFF

async def reset_dut(dut):
    dut.rst_ni.value = 0
    dut.start_i.value = 0
    dut.op_i.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    await Timer(20, unit='ns')
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

async def drive_muldiv(dut, op, a, b):
    dut.op_i.value = op
    dut.a_i.value = a
    dut.b_i.value = b
    dut.start_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.start_i.value = 0

    if op in (MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_MULW):
        # MUL is combinational: result ready once inputs settle.
        await Timer(1, unit='ns')
        return dut.mul_result_o.value

    # DIV: wait for the completion pulse, then read the engine result.
    timeout = 100
    while dut.div_valid_o.value == 0:
        await RisingEdge(dut.clk_i)
        timeout -= 1
        if timeout == 0:
            assert False, ("Timeout waiting for muldiv div_valid_o")

    return dut.div_result_o.value

def to_signed64(val):
    val = int(val)
    if val > 0x7FFFFFFFFFFFFFFF:
        return val - 0x10000000000000000
    return val

def to_signed32(val):
    val = int(val) & MASK32
    if val > 0x7FFFFFFF:
        return val - 0x100000000
    return val

@cocotb.test()
async def test_muldiv_basic(dut):
    """Basic multiplication and division verification"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # Simple MUL
    res = await drive_muldiv(dut, MD_MUL, 10, 20)
    assert res == 200, f"Expected 200, got {res}"

    # Simple DIV
    res = await drive_muldiv(dut, MD_DIV, 200, 10)
    assert res == 20, f"Expected 20, got {res}"

@cocotb.test()
async def test_muldiv_divide_by_zero(dut):
    """Test Division by Zero (Corner Case) — RV64: -1 is 64-bit all-ones"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # DIV by 0 -> -1 (0xFFFF...FFFF)
    res = await drive_muldiv(dut, MD_DIV, 100, 0)
    assert res == MASK64, f"DIV by 0: Expected -1, got {res}"

    # DIVU by 0 -> Max Int
    res = await drive_muldiv(dut, MD_DIVU, 100, 0)
    assert res == MASK64, f"DIVU by 0: Expected Max, got {res}"

    # REM by 0 -> Dividend
    res = await drive_muldiv(dut, MD_REM, 100, 0)
    assert res == 100, f"REM by 0: Expected 100, got {res}"

@cocotb.test()
async def test_muldiv_overflow(dut):
    """Test Overflow Case (MIN_INT / -1) — 64-bit"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # MIN_INT / -1 -> MIN_INT (Overflow)
    min_int = 0x8000000000000000
    minus_one = MASK64

    res = await drive_muldiv(dut, MD_DIV, min_int, minus_one)
    assert res == min_int, f"Overflow DIV: Expected MIN_INT, got {res}"

    res = await drive_muldiv(dut, MD_REM, min_int, minus_one)
    assert res == 0, f"Overflow REM: Expected 0, got {res}"

@cocotb.test()
async def test_muldiv_mixed_signs(dut):
    """Test Signed/Unsigned Mixed Operations — 64-bit operands"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # -10 / 2 = -5
    res = await drive_muldiv(dut, MD_DIV, MASK64 - 9, 2)
    dut._log.info(f"-10/2: Got {hex(res)} ({to_signed64(res)})")
    assert to_signed64(res) == -5, f"-10/2: Expected -5, got {to_signed64(res)}"

    # 10 / -2 = -5
    res = await drive_muldiv(dut, MD_DIV, 10, MASK64 - 1)
    dut._log.info(f"10/-2: Got {hex(res)} ({to_signed64(res)})")
    assert to_signed64(res) == -5, f"10/-2: Expected -5, got {to_signed64(res)}"

    # -10 / -2 = 5
    res = await drive_muldiv(dut, MD_DIV, MASK64 - 9, MASK64 - 1)
    dut._log.info(f"-10/-2: Got {hex(res)} ({to_signed64(res)})")
    assert res == 5, f"-10/-2: Expected 5, got {to_signed64(res)}"

@cocotb.test()
async def test_muldiv_word_ops(dut):
    """RV64M W-suffix ops: 32-bit wrap, sign-extended"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # MULW: low 32 bits, sign-extended
    res = await drive_muldiv(dut, MD_MULW, 100000, 100000)
    assert to_signed32(res) == to_signed32(100000 * 100000), f"MULW got {hex(res)}"

    # DIVW: -2^31 / -1 -> -2^31 (32-bit overflow rule)
    res = await drive_muldiv(dut, MD_DIVW, 0x80000000, MASK32)
    assert res == 0xFFFFFFFF80000000, f"DIVW overflow: got {hex(res)}"

    # DIVW by 0 -> all-ones
    res = await drive_muldiv(dut, MD_DIVW, 100, 0)
    assert res == MASK64, f"DIVW by 0: got {hex(res)}"

    # REMW: -10 % 3 (32-bit) = -1 sign-extended
    res = await drive_muldiv(dut, MD_REMW, MASK32 - 9, 3)
    assert res == MASK64, f"REMW: got {hex(res)}"

@cocotb.test()
async def test_muldiv_random(dut):
    """Randomized Soak Test"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    for _ in range(50):
        a = random.randint(0, MASK64)
        b = random.randint(1, MASK64)  # Avoid 0 here to check normal logic

        # MUL
        await drive_muldiv(dut, MD_MUL, a, b)

        # DIVU with model check
        res = await drive_muldiv(dut, MD_DIVU, a, b)
        assert int(res) == a // b, f"DIVU {a:#x}/{b:#x}: got {hex(res)}"
