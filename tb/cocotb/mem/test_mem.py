import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Memory Width Constants (from ironcore_pkg)
MEM_BYTE = 0
MEM_HALF = 1
MEM_WORD = 2

# Struct Packing Helper
def pack_ex_mem_reg(valid=0, reg_write=0, mem_unsigned=0, mem_width=0, 
                   mem_write=0, mem_read=0, rd_addr=0, rs2_data=0, 
                   alu_result=0, pc=0):
    val = 0
    val |= (valid & 1) << 0
    val |= (reg_write & 1) << 1
    val |= (mem_unsigned & 1) << 2
    val |= (mem_width & 3) << 3
    val |= (mem_write & 1) << 5
    val |= (mem_read & 1) << 6
    val |= (rd_addr & 0x1F) << 7
    val |= (rs2_data & 0xFFFFFFFF) << 12
    val |= (alu_result & 0xFFFFFFFF) << 44
    val |= (pc & 0xFFFFFFFF) << 76
    return val

async def reset_dut(dut):
    dut.rst_ni.value = 0
    dut.ex_mem_reg_i.value = 0
    dut.dwb_ack_i.value = 0
    dut.dwb_dat_i.value = 0
    
    await Timer(20, units='ns')
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)

async def drive_mem_req(dut, read, write, width, unsigned, addr, wdata=0):
    # Drive Request
    val = pack_ex_mem_reg(
        valid=1,
        mem_read=read,
        mem_write=write,
        mem_width=width,
        mem_unsigned=unsigned,
        alu_result=addr,
        rs2_data=wdata
    )
    dut.ex_mem_reg_i.value = val
    
    await RisingEdge(dut.clk_i)

async def clear_mem_req(dut):
    val_idle = pack_ex_mem_reg(valid=0)
    dut.ex_mem_reg_i.value = val_idle
    await RisingEdge(dut.clk_i)
    
@cocotb.test()
async def test_mem_aligned_rw(dut):
    """Test aligned Read/Write for Byte/Half/Word"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # Write Word @ 0x100
    await drive_mem_req(dut, 0, 1, MEM_WORD, 0, 0x100, 0xAABBCCDD)
    await Timer(1, units='ns')
    
    assert dut.dwb_cyc_o.value == 1
    assert dut.dwb_stb_o.value == 1
    assert dut.dwb_we_o.value == 1
    assert dut.dwb_dat_o.value == 0xAABBCCDD
    assert dut.dwb_sel_o.value == 0xF
    
    # Acknowledge
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.dwb_ack_i.value = 0
    await clear_mem_req(dut) # Transaction done
    await RisingEdge(dut.clk_i) # Wait for state return IDLE

    # Read Half @ 0x102 (Upper half of word) -> Offset 2
    await drive_mem_req(dut, 1, 0, MEM_HALF, 0, 0x102)
    await Timer(1, units='ns')
    
    assert dut.dwb_sel_o.value == 0xC # 1100
    
    dut.dwb_dat_i.value = 0xAABBCCDD
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    # Result available next cycle?
    # Logic: load_data_raw = {{16{load_half[15]}}, load_half}
    # Offset 2 selects dwb_dat_i[31:16] = 0xAABB
    # Signed ext of 0xAABB -> 0xFFFFAABB
    await Timer(1, units='ns') 
    assert dut.mem_rdata_o.value == 0xFFFFAABB
    await clear_mem_req(dut)

@cocotb.test()
async def test_mem_misaligned_trap(dut):
    """Test Misaligned Access Trap Generation"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # Word access @ 0x101 (Misaligned)
    # Note: Assertions might fire here. In simulation we ignore them or check wave.
    await drive_mem_req(dut, 1, 0, MEM_WORD, 0, 0x101)
    
    await Timer(1, units='ns')
    assert dut.mem_exc_valid_o.value == 1
    assert dut.mem_exc_cause_o.value == 4 # EXC_LOAD_MISALIGN (Check pkg)
    assert dut.dwb_stb_o.value == 0 # Should NOT start bus transaction
    
    await clear_mem_req(dut)
    await RisingEdge(dut.clk_i)

@cocotb.test()
async def test_mem_backpressure(dut):
    """Test Bus Wait States (Backpressure)"""
    cocotb.start_soon(Clock(dut.clk_i, 10, units='ns').start())
    await reset_dut(dut)
    
    # Write Word
    await drive_mem_req(dut, 0, 1, MEM_WORD, 0, 0x200, 0x12345678)
    
    # Wait 5 cycles before ACK
    for _ in range(5):
        await Timer(1, units='ns')
        assert dut.dwb_stb_o.value == 1
        assert dut.mem_stall_o.value == 1 # Should stall pipeline
        await RisingEdge(dut.clk_i)
        
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.dwb_ack_i.value = 0
    await clear_mem_req(dut)
    
    await Timer(1, units='ns')
    assert dut.mem_stall_o.value == 0
    assert dut.dwb_stb_o.value == 0
