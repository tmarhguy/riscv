import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Memory Width Constants (from rv64xo3_pkg)
MEM_BYTE = 0
MEM_HALF = 1
MEM_WORD = 2
MEM_DWORD = 3

# Struct Packing Helper: mirrors packed ex_mem_reg_t in rv64xo3_pkg.sv
# (packed order MSB->LSB: pc[64], alu_result[64], rs2_data[64], rd[5],
#  mem_read, mem_write, mem_width[2], mem_unsigned, reg_write, valid)
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
    val |= (rs2_data & 0xFFFFFFFFFFFFFFFF) << 12
    val |= (alu_result & 0xFFFFFFFFFFFFFFFF) << 76
    val |= (pc & 0xFFFFFFFFFFFFFFFF) << 140
    return val

async def reset_dut(dut):
    dut.rst_ni.value = 0
    dut.ex_mem_reg_i.value = 0
    dut.dwb_ack_i.value = 0
    dut.dwb_dat_i.value = 0
    
    await Timer(20, unit='ns')
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

async def do_ack(dut):
    """Acknowledge one bus transaction. ack is held for two edges so it is
    seen in WAIT_ACK regardless of whether the core just entered it."""
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)
    dut.dwb_ack_i.value = 0
    await Timer(1, unit='ns')
    
@cocotb.test()
async def test_mem_aligned_rw(dut):
    """Test aligned Read/Write for Byte/Half/Word"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)
    
    # Write Word @ 0x100
    await drive_mem_req(dut, 0, 1, MEM_WORD, 0, 0x100, 0xAABBCCDD)
    await Timer(1, unit='ns')
    
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
    await Timer(1, unit='ns')
    
    assert dut.dwb_sel_o.value == 0xC # 1100
    
    dut.dwb_dat_i.value = 0xAABBCCDD
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    # Result available next cycle?
    # Logic: load_data_raw = {{48{load_half[15]}}, load_half} (RV64: 64-bit sext)
    # Offset 2 selects dwb_dat_i[31:16] = 0xAABB
    # Signed ext of 0xAABB -> 0xFFFFFFFFFFFFAABB
    await Timer(1, unit='ns') 
    assert dut.mem_rdata_o.value == 0xFFFFFFFFFFFFAABB
    await clear_mem_req(dut)

    # Write DWORD @ 0x108 (RV64) — full 8-byte lanes
    await drive_mem_req(dut, 0, 1, MEM_DWORD, 0, 0x108, 0x1122334455667788)
    await Timer(1, unit='ns')

    assert dut.dwb_cyc_o.value == 1
    assert dut.dwb_we_o.value == 1
    assert dut.dwb_dat_o.value == 0x1122334455667788
    assert dut.dwb_sel_o.value == 0xFF

    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.dwb_ack_i.value = 0
    await clear_mem_req(dut)
    await RisingEdge(dut.clk_i)

@cocotb.test()
async def test_mem_misaligned_hw(dut):
    """Test hardware misaligned access (split bus transactions, no trap)"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)

    # Misaligned accesses must NOT trap anymore (handled in HW)
    # DWORD store @ 0x101 (bytes 1..8): two transactions.
    await drive_mem_req(dut, 0, 1, MEM_DWORD, 0, 0x101, 0x1122334455667788)
    await Timer(1, unit='ns')

    assert dut.mem_exc_valid_o.value == 0
    # Txn 0: word 0x100, bytes 1..7
    assert dut.dwb_adr_o.value == 0x100
    assert dut.dwb_sel_o.value == 0xFE
    assert dut.dwb_dat_o.value == 0x2233445566778800
    await do_ack(dut)

    # Txn 1: word 0x104, byte 8
    assert dut.dwb_stb_o.value == 1
    assert dut.dwb_adr_o.value == 0x104
    assert dut.dwb_sel_o.value == 0x10
    assert dut.dwb_dat_o.value == 0x1100000000
    await do_ack(dut)

    await clear_mem_req(dut)
    await RisingEdge(dut.clk_i)

    # DWORD load @ 0x101: bytes 1..7 from word 0x100, byte 8 from 0x104.
    await drive_mem_req(dut, 1, 0, MEM_DWORD, 0, 0x101)
    await Timer(1, unit='ns')

    assert dut.mem_exc_valid_o.value == 0
    assert dut.dwb_adr_o.value == 0x100

    dut.dwb_dat_i.value = 0xF1F2F3F4F5F6F708
    await do_ack(dut)

    assert dut.dwb_stb_o.value == 1
    assert dut.dwb_adr_o.value == 0x104

    dut.dwb_dat_i.value = 0x000000A900000000  # byte 8 lands on bus byte 4
    await do_ack(dut)
    # Merged: low 7 bytes F1..F7, top byte A9
    assert dut.mem_rdata_o.value == 0xA9F1F2F3F4F5F6F7
    await clear_mem_req(dut)
    await RisingEdge(dut.clk_i)

@cocotb.test()
async def test_mem_backpressure(dut):
    """Test Bus Wait States (Backpressure)"""
    cocotb.start_soon(Clock(dut.clk_i, 10, unit='ns').start())
    await reset_dut(dut)
    
    # Write Word
    await drive_mem_req(dut, 0, 1, MEM_WORD, 0, 0x200, 0x12345678)
    
    # Wait 5 cycles before ACK
    for _ in range(5):
        await Timer(1, unit='ns')
        assert dut.dwb_stb_o.value == 1
        assert dut.mem_stall_o.value == 1 # Should stall pipeline
        await RisingEdge(dut.clk_i)
        
    dut.dwb_ack_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.dwb_ack_i.value = 0
    await clear_mem_req(dut)
    
    await Timer(1, unit='ns')
    assert dut.mem_stall_o.value == 0
    assert dut.dwb_stb_o.value == 0
