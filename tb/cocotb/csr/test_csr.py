import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Constants
CSR_MSTATUS   = 0x300
CSR_MIE       = 0x304
CSR_MTVEC     = 0x305
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
    await Timer(1, units='ns') # Combinational read
    return dut.csr_rdata_o.value.integer

@cocotb.test()
async def test_csr_init(dut):
    """Test Reset Values"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    assert await read_csr(dut, CSR_MSTATUS) == 0
    assert await read_csr(dut, CSR_MIE) == 0
    assert await read_csr(dut, CSR_MTVEC) == 0
    # Vendor IDs
    assert await read_csr(dut, CSR_MVENDORID) == 0
    assert await read_csr(dut, CSR_MIMPID) == 0x01000001

@cocotb.test()
async def test_csr_mstatus_mask(dut):
    """Test MSTATUS writable bits (MIE bit 3, MPIE bit 7 only)"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Try to write all 1s
    await write_csr(dut, CSR_MSTATUS, 0xFFFFFFFF)
    await RisingEdge(dut.clk_i)
    val = await read_csr(dut, CSR_MSTATUS)
    
    # Only bits 3 and 7 should be set (0x88)
    if val != 0x88:
        raise TestFailure(f"MSTATUS mask failed. Got {val:#x}, expected 0x88")

@cocotb.test()
async def test_csr_mtvec_mode(dut):
    """Test MTVEC mode locking (Direct mode only)"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Try to set mode bits 1:0 to 1 (Vectored) -> should be forced to 0
    target = 0x80000001
    await write_csr(dut, CSR_MTVEC, target)
    await RisingEdge(dut.clk_i)
    val = await read_csr(dut, CSR_MTVEC)
    
    if (val & 3) != 0:
        raise TestFailure(f"MTVEC mode bits not locked to 0. Got {val:#x}")
    if (val & ~3) != (target & ~3):
        raise TestFailure(f"MTVEC base address incorrect. Got {val:#x}")

@cocotb.test()
async def test_csr_mret_logic(dut):
    """Test MRET restoring status"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # 1. Set MIE=1
    await write_csr(dut, CSR_MSTATUS, 0x8) # MIE=1
    assert await read_csr(dut, CSR_MSTATUS) == 0x8
    
    # 2. Trap taken (Hardware logic)
    dut.trap_taken_i.value = 1
    dut.trap_pc_i.value = 0x100
    dut.trap_cause_i.value = 5
    await RisingEdge(dut.clk_i)
    dut.trap_taken_i.value = 0
    
    # Verify MIE->MPIE, MIE->0
    status = await read_csr(dut, CSR_MSTATUS)
    if (status & 0x8) != 0: raise TestFailure("Trap did not clear MIE")
    if (status & 0x80) != 0x80: raise TestFailure("Trap did not save MIE to MPIE")
    
    # 3. Exec MRET
    dut.mret_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.mret_i.value = 0
    
    # Verify MPIE->MIE, MPIE->1
    status = await read_csr(dut, CSR_MSTATUS)
    if (status & 0x8) != 0x8: raise TestFailure("MRET did not restore MIE")
    if (status & 0x80) != 0x80: raise TestFailure("MRET did not set MPIE to 1")

@cocotb.test()
async def test_perf_counters(dut):
    """Test Cycle Counter"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    start_cyc = await read_csr(dut, CSR_CYCLE)
    await Timer(100, units='ns') # 10 cycles
    end_cyc = await read_csr(dut, CSR_CYCLE)
    
    if end_cyc <= start_cyc:
        raise TestFailure(f"Cycle counter not incrementing: {start_cyc} -> {end_cyc}")

@cocotb.test()
async def test_csr_bit_ops(dut):
    """Test CSRRS (Set) and CSRRC (Clear)"""
    clock = Clock(dut.clk_i, 10, units="ns")
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
