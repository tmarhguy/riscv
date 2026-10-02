"""Predictor state and recovery-facing interface checks."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


@cocotb.test()
async def test_gshare_btb_ras(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    dut.rst_ni.value = 0
    dut.instr_valid_i.value = 0
    dut.update_en_i.value = 0
    for signal in (dut.update_pc_i, dut.update_index_i, dut.update_branch_i,
                   dut.update_taken_i, dut.update_target_i, dut.update_call_i,
                   dut.update_return_i, dut.update_link_i):
        signal.value = 0
    dut.pc_i[0].value = 0x40
    dut.pc_i[1].value = 0x44
    dut.instr_i[0].value = 0x00000463  # beq x0,x0,+8
    dut.instr_i[1].value = 0x00008067  # ret
    await RisingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    dut.instr_valid_i.value = 1
    await Timer(1, unit="ns")
    index = int(dut.pred_index_o[0].value)
    assert index == 0x10
    assert int(dut.pred_taken_o[0].value) == 0
    assert int(dut.pred_taken_o[1].value) == 0

    async def update(pc, branch=0, taken=1, target=0x90, call=0, ret=0, link=0x48):
        await FallingEdge(dut.clk_i)
        dut.update_en_i.value = 1
        dut.update_pc_i.value = pc
        dut.update_index_i.value = index
        dut.update_branch_i.value = branch
        dut.update_taken_i.value = taken
        dut.update_target_i.value = target
        dut.update_call_i.value = call
        dut.update_return_i.value = ret
        dut.update_link_i.value = link
        await RisingEdge(dut.clk_i)
        await FallingEdge(dut.clk_i)
        dut.update_en_i.value = 0
        await Timer(1, unit="ns")

    await update(0x40, branch=1)
    assert int(dut.pred_index_o[0].value) == (0x10 ^ 1)
    # An update trains the saved fetch index, despite changed current history.
    dut.pc_i[0].value = 0x44
    await Timer(1, unit="ns")
    assert int(dut.pred_index_o[0].value) == index
    assert int(dut.pred_taken_o[0].value) == 1
    await update(0x44, target=0x120)
    assert int(dut.pred_taken_o[1].value) == 1
    assert int(dut.pred_target_o[1].value) == 0x120
    # Same BTB index, different tag must miss.
    dut.pc_i[1].value = 0x444
    await Timer(1, unit="ns")
    assert int(dut.pred_taken_o[1].value) == 0
    dut.pc_i[1].value = 0x44
    await update(0x80, call=1, link=0x84)
    assert int(dut.pred_target_o[1].value) == 0x84
    await update(0x90, call=1, link=0x94)
    assert int(dut.pred_target_o[1].value) == 0x94
    await update(0x44, ret=1)
    assert int(dut.pred_target_o[1].value) == 0x84
    await update(0x44, ret=1, target=0x140)
    assert int(dut.pred_target_o[1].value) == 0x140
    # Empty returns are harmless; overflowing calls keep the newest 16 links.
    await update(0x44, ret=1)
    for i in range(18):
        await update(0x80, call=1, link=0x200 + 4*i)
    for i in reversed(range(2, 18)):
        assert int(dut.pred_target_o[1].value) == 0x200 + 4*i
        await update(0x44, ret=1)
    assert int(dut.pred_target_o[1].value) == 0x90
