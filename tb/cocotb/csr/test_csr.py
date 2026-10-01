import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Constants
CSR_MSTATUS   = 0x300
CSR_MISA      = 0x301
CSR_MIE       = 0x304
CSR_MTVEC     = 0x305
CSR_SSTATUS   = 0x100
CSR_SSCRATCH  = 0x140
CSR_MSCRATCH  = 0x340
CSR_MEPC      = 0x341
CSR_MCAUSE    = 0x342
CSR_MIP       = 0x344
CSR_CYCLE     = 0xC00
CSR_CYCLEH    = 0xC80
CSR_INSTRET   = 0xC02
CSR_INSTRETH  = 0xC82
CSR_MVENDORID = 0xF11
CSR_MARCHID   = 0xF12
CSR_MIMPID    = 0xF13
CSR_MHARTID   = 0xF14

CSRRW  = 0b001
CSRRS  = 0b010
CSRRC  = 0b011

async def reset_dut(dut):
    dut.rst_ni.value = 0
    dut.csr_wen_i.value = 0
    dut.trap_taken_i.value = 0
    dut.mret_i.value = 0
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

async def write_csr(dut, addr, data):
    dut.csr_addr_i.value = addr
    dut.csr_wen_i.value = 1
    dut.csr_op_i.value = CSRRW
    dut.csr_wdata_i.value = data
    await RisingEdge(dut.clk_i)
    dut.csr_wen_i.value = 0

async def read_csr(dut, addr):
    dut.csr_addr_i.value = addr
    dut.csr_wen_i.value = 0
    await Timer(1, unit='ns') # Combinational read
    return dut.csr_rdata_o.value.integer

# MSTATUS reads OR in hardwired RV64 XL fields (SXL=UXL=2).
MSTATUS_RO_XL = 0xA00000000
# ...plus MIE/MPIE set (e.g. after writing all-ones).
MSTATUS_ALL = 0xA00000088


@cocotb.test()
async def test_csr_init(dut):
    """Test Reset Values"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    assert await read_csr(dut, CSR_MSTATUS) == MSTATUS_RO_XL
    assert await read_csr(dut, CSR_MIE) == 0
    assert await read_csr(dut, CSR_MTVEC) == 0
    # Vendor IDs
    assert await read_csr(dut, CSR_MVENDORID) == 0
    assert await read_csr(dut, CSR_MIMPID) == 0x01000001

@cocotb.test()
async def test_csr_misa_scratch(dut):
    """Test MISA encoding and scratch register R/W"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # MISA: MXL=2 (RV64) + I + M only; no C/A/U/S claims
    misa = await read_csr(dut, CSR_MISA)
    assert misa >> 62 == 2
    assert (misa >> 8) & 1 == 1   # I
    assert (misa >> 12) & 1 == 1  # M
    assert misa & ((1 << 2) | (1 << 0) | (1 << 20) | (1 << 18) | (1 << 5)) == 0

    # Scratch registers round-trip arbitrary values
    await write_csr(dut, CSR_SSCRATCH, 0xDEADBEEF)
    assert await read_csr(dut, CSR_SSCRATCH) == 0xDEADBEEF
    await write_csr(dut, CSR_MSCRATCH, 0x12345678)
    assert await read_csr(dut, CSR_MSCRATCH) == 0x12345678

    # SSTATUS exposes UXL=2 (bit 33) via the mstatus hardwire
    sstatus = await read_csr(dut, CSR_SSTATUS)
    assert (sstatus >> 32) & 0x3 == 0x2

@cocotb.test()
async def test_csr_mstatus_mask(dut):
    """Test MSTATUS writable bits (MIE bit 3, MPIE bit 7 only)"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Try to write all 1s
    await write_csr(dut, CSR_MSTATUS, 0xFFFFFFFF)
    await RisingEdge(dut.clk_i)
    val = await read_csr(dut, CSR_MSTATUS)

    # Only bits 3 and 7 writable; XL fields hardwired (SXL=UXL=2)
    if val != MSTATUS_ALL:
        assert False, (f"MSTATUS mask failed. Got {val:#x}, expected {MSTATUS_ALL:#x}")

@cocotb.test()
async def test_csr_mtvec_mode(dut):
    """Test MTVEC mode locking (Direct mode only)"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Try to set mode bits 1:0 to 1 (Vectored) -> should be forced to 0
    target = 0x80000001
    await write_csr(dut, CSR_MTVEC, target)
    await RisingEdge(dut.clk_i)
    val = await read_csr(dut, CSR_MTVEC)
    
    if (val & 3) != 0:
        assert False, (f"MTVEC mode bits not locked to 0. Got {val:#x}")
    if (val & ~3) != (target & ~3):
        assert False, (f"MTVEC base address incorrect. Got {val:#x}")

@cocotb.test()
async def test_csr_mret_logic(dut):
    """Test MRET restoring status"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # 1. Set MIE=1
    await write_csr(dut, CSR_MSTATUS, 0x8) # MIE=1
    assert await read_csr(dut, CSR_MSTATUS) == (MSTATUS_RO_XL | 0x8)
    
    # 2. Trap taken (Hardware logic)
    dut.trap_taken_i.value = 1
    dut.trap_pc_i.value = 0x100
    dut.trap_cause_i.value = 5
    await RisingEdge(dut.clk_i)
    dut.trap_taken_i.value = 0
    
    # Verify MIE->MPIE, MIE->0
    status = await read_csr(dut, CSR_MSTATUS)
    if (status & 0x8) != 0: assert False, ("Trap did not clear MIE")
    if (status & 0x80) != 0x80: assert False, ("Trap did not save MIE to MPIE")
    
    # 3. Exec MRET
    dut.mret_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.mret_i.value = 0
    
    # Verify MPIE->MIE, MPIE->1
    status = await read_csr(dut, CSR_MSTATUS)
    if (status & 0x8) != 0x8: assert False, ("MRET did not restore MIE")
    if (status & 0x80) != 0x80: assert False, ("MRET did not set MPIE to 1")

@cocotb.test()
async def test_perf_counters(dut):
    """Test Cycle Counter"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    start_cyc = await read_csr(dut, CSR_CYCLE)
    await Timer(100, unit='ns') # 10 cycles
    end_cyc = await read_csr(dut, CSR_CYCLE)
    
    if end_cyc <= start_cyc:
        assert False, (f"Cycle counter not incrementing: {start_cyc} -> {end_cyc}")

@cocotb.test()
async def test_csr_bit_ops(dut):
    """Test CSRRS (Set) and CSRRC (Clear)"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Start clean
    await write_csr(dut, CSR_MIE, 0)
    
    # Set bit 7 (MTIE)
    dut.csr_addr_i.value = CSR_MIE
    dut.csr_wen_i.value = 1
    dut.csr_op_i.value = CSRRS
    dut.csr_wdata_i.value = 0x80
    await RisingEdge(dut.clk_i)
    dut.csr_wen_i.value = 0
    
    assert await read_csr(dut, CSR_MIE) == 0x80
    
    # Clear bit 7
    dut.csr_wen_i.value = 1
    dut.csr_op_i.value = CSRRC
    dut.csr_wdata_i.value = 0x80
    await RisingEdge(dut.clk_i)
    dut.csr_wen_i.value = 0
    
    assert await read_csr(dut, CSR_MIE) == 0
