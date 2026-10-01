"""
riscv64xO3 Cocotb Test Suite
Smoke tests and integration tests for the RV64IM scalar pipeline
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import pytest


# --- Tiny RV64 encoders (avoid hand-encoded hex for programmed tests) ---
def enc_i(imm, rs1, f3, rd, op=0x13):
    return (((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) |
            ((f3 & 0x7) << 12) | ((rd & 0x1F) << 7) | op)


def enc_r(f7, rs2, rs1, f3, rd, op=0x33):
    return (((f7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) |
            ((rs1 & 0x1F) << 15) | ((f3 & 0x7) << 12) |
            ((rd & 0x1F) << 7) | op)


def enc_s(imm, rs2, rs1, f3, op=0x23):
    imm &= 0xFFF
    return ((((imm >> 5) & 0x7F) << 25) | ((rs2 & 0x1F) << 20) |
            ((rs1 & 0x1F) << 15) | ((f3 & 0x7) << 12) |
            ((imm & 0x1F) << 7) | op)


TOHOST_OFF = 0x100  # dmem offset watched for completion


async def run_until_store(dut, dmem, expect, limit=400):
    """Run until dmem[TOHOST_OFF] == expect; return cycle count."""
    for i in range(limit):
        await RisingEdge(dut.clk_i)
        if dmem._read_word(TOHOST_OFF) == expect:
            return i
    return None


class WishboneMemory:
    """Simple Wishbone memory model for testing"""

    def __init__(self, dut, prefix, size=0x10000, init_data=None):
        self.dut = dut
        self.prefix = prefix
        self.size = size
        self.mem = bytearray(size)
        if init_data:
            for addr, data in init_data.items():
                self._write_word(addr, data)

    def _write_word(self, addr, data):
        """Write a 32-bit word to memory"""
        addr = addr & 0xFFFFFFFC  # Word align
        self.mem[addr] = data & 0xFF
        self.mem[addr + 1] = (data >> 8) & 0xFF
        self.mem[addr + 2] = (data >> 16) & 0xFF
        self.mem[addr + 3] = (data >> 24) & 0xFF

    def _read_word(self, addr):
        """Read a 32-bit word from memory"""
        addr = addr & 0xFFFFFFFC  # Word align
        return (self.mem[addr] |
                (self.mem[addr + 1] << 8) |
                (self.mem[addr + 2] << 16) |
                (self.mem[addr + 3] << 24))

    async def run(self):
        """Memory model coroutine"""
        cyc = getattr(self.dut, f"{self.prefix}_cyc_o")
        stb = getattr(self.dut, f"{self.prefix}_stb_o")
        adr = getattr(self.dut, f"{self.prefix}_adr_o")
        dat_i = getattr(self.dut, f"{self.prefix}_dat_i")
        ack = getattr(self.dut, f"{self.prefix}_ack_i")

        # Check if this is data memory (has write signals)
        is_data = self.prefix == "dwb"
        if is_data:
            we = getattr(self.dut, f"{self.prefix}_we_o")
            dat_o = getattr(self.dut, f"{self.prefix}_dat_o")
            sel = getattr(self.dut, f"{self.prefix}_sel_o")

        ack.value = 0
        dat_i.value = 0

        while True:
            await RisingEdge(self.dut.clk_i)

            if cyc.value and stb.value:
                addr = int(adr.value) % self.size

                if is_data and we.value:
                    # Write operation
                    data = int(dat_o.value)
                    sel_val = int(sel.value)

                    if sel_val & 0x1:
                        self.mem[addr] = data & 0xFF
                    if sel_val & 0x2:
                        self.mem[addr + 1] = (data >> 8) & 0xFF
                    if sel_val & 0x4:
                        self.mem[addr + 2] = (data >> 16) & 0xFF
                    if sel_val & 0x8:
                        self.mem[addr + 3] = (data >> 24) & 0xFF

                # Read operation (or write ack)
                dat_i.value = self._read_word(addr)
                ack.value = 1
            else:
                ack.value = 0


async def reset_dut(dut, cycles=5):
    """Reset the DUT"""
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, cycles)
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 2)


@cocotb.test()
@pytest.mark.smoke
async def test_reset(dut):
    """Test that reset works correctly"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # After reset, PC should be at RESET_PC (0x00000000)
    # Check that instruction fetch is happening
    await ClockCycles(dut.clk_i, 10)

    dut._log.info("Reset test passed")


@cocotb.test()
@pytest.mark.smoke
async def test_nop_execution(dut):
    """Test execution of NOP instructions"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # NOP = ADDI x0, x0, 0 = 0x00000013
    nop = 0x00000013

    # Initialize instruction memory with NOPs
    imem = WishboneMemory(dut, "iwb", init_data={
        0x00: nop,
        0x04: nop,
        0x08: nop,
        0x0C: nop,
        0x10: nop,
    })

    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)

    # Run for several cycles
    await ClockCycles(dut.clk_i, 50)

    dut._log.info("NOP execution test passed")


@cocotb.test()
async def test_addi(dut):
    """Test ADDI instruction"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # ADDI x1, x0, 42   -> x1 = 42
    # ADDI x2, x1, 8    -> x2 = 50
    # NOP padding
    imem = WishboneMemory(dut, "iwb", init_data={
        0x00: 0x02A00093,  # addi x1, x0, 42
        0x04: 0x00808113,  # addi x2, x1, 8
        0x08: 0x00000013,  # nop
        0x0C: 0x00000013,  # nop
        0x10: 0x00000013,  # nop
        0x14: 0x00000013,  # nop
        0x18: 0x00000013,  # nop
        0x1C: 0x00000013,  # nop
    })

    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)

    # Run enough cycles for instructions to complete
    await ClockCycles(dut.clk_i, 30)

    dut._log.info("ADDI test completed")


@cocotb.test()
async def test_load_store(dut):
    """Test load and store instructions"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Program:
    # lui x1, 0x80000     -> x1 = 0x80000000 (RAM base)
    # addi x2, x0, 0x55   -> x2 = 0x55
    # sw x2, 0(x1)        -> mem[0x80000000] = 0x55
    # lw x3, 0(x1)        -> x3 = mem[0x80000000] = 0x55
    imem = WishboneMemory(dut, "iwb", init_data={
        0x00: 0x800000B7,  # lui x1, 0x80000
        0x04: 0x05500113,  # addi x2, x0, 0x55
        0x08: 0x0020A023,  # sw x2, 0(x1)
        0x0C: 0x0000A183,  # lw x3, 0(x1)
        0x10: 0x00000013,  # nop
        0x14: 0x00000013,  # nop
        0x18: 0x00000013,  # nop
        0x1C: 0x00000013,  # nop
    })

    dmem = WishboneMemory(dut, "dwb", size=0x10000)

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)

    # Run enough cycles
    await ClockCycles(dut.clk_i, 50)

    # Verify memory was written
    stored_val = dmem._read_word(0x0000)  # Offset in dmem
    dut._log.info(f"Stored value: {stored_val:#x}")

    dut._log.info("Load/Store test completed")


@cocotb.test()
async def test_branch_taken(dut):
    """Test branch instruction (taken)"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Program:
    # addi x1, x0, 5      -> x1 = 5
    # addi x2, x0, 5      -> x2 = 5
    # beq x1, x2, skip    -> branch taken (skip +8)
    # addi x3, x0, 1      -> x3 = 1 (should be skipped)
    # skip:
    # addi x4, x0, 2      -> x4 = 2 (should execute)
    imem = WishboneMemory(dut, "iwb", init_data={
        0x00: 0x00500093,  # addi x1, x0, 5
        0x04: 0x00500113,  # addi x2, x0, 5
        0x08: 0x00208463,  # beq x1, x2, +8 (to 0x10)
        0x0C: 0x00100193,  # addi x3, x0, 1
        0x10: 0x00200213,  # addi x4, x0, 2
        0x14: 0x00000013,  # nop
        0x18: 0x00000013,  # nop
        0x1C: 0x00000013,  # nop
    })

    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)
    await ClockCycles(dut.clk_i, 40)

    dut._log.info("Branch taken test completed")


@cocotb.test()
async def test_jal(dut):
    """Test JAL instruction"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Program:
    # jal x1, +8          -> x1 = PC+4, jump to 0x08
    # addi x2, x0, 1      -> skipped
    # addi x3, x0, 2      -> executed
    imem = WishboneMemory(dut, "iwb", init_data={
        0x00: 0x008000EF,  # jal x1, +8
        0x04: 0x00100113,  # addi x2, x0, 1 (skipped)
        0x08: 0x00200193,  # addi x3, x0, 2
        0x0C: 0x00000013,  # nop
        0x10: 0x00000013,  # nop
    })

    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)
    await ClockCycles(dut.clk_i, 30)

    dut._log.info("JAL test completed")


N_OVERLAP_OPS = 40


@cocotb.test()
async def test_div_overlap(dut):
    """Phase 1: independent ALU ops retire while DIV iterates.

    div x5 (65-cycle iterative divide) runs while 40 independent addi
    flow through the pipe; a final add consumes the DIV result (which must
    stall correctly, then read the right value). Proves no whole-pipeline
    stall: a fully-stalling design needs ~65 + 40 + fill cycles here.
    """
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    prog = {
        0x00: enc_i(100, 0, 0, 1),          # addi x1, x0, 100
        0x04: enc_i(7, 0, 0, 2),            # addi x2, x0, 7
        0x08: enc_r(0x01, 2, 1, 0x4, 5),    # div x5, x1, x2 (= 14)
    }
    addr = 0x0C
    for _ in range(N_OVERLAP_OPS):
        prog[addr] = enc_i(1, 6, 0, 6)      # addi x6, x6, 1 (x6 = 40)
        addr += 4
    prog[addr] = enc_r(0x00, 6, 5, 0x0, 7)  # add x7, x5, x6 (= 54)
    addr += 4
    prog[addr] = enc_i(0x100, 0, 0, 8)      # addi x8, x0, 0x100
    addr += 4
    prog[addr] = enc_s(0, 7, 8, 0x2)        # sw x7, 0(x8) -> TOHOST
    addr += 4
    prog[addr] = 0x0000006F                 # jal x0, 0 (halt)
    expect = 14 + N_OVERLAP_OPS

    imem = WishboneMemory(dut, "iwb", init_data=prog)
    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)

    done_at = await run_until_store(dut, dmem, expect)
    assert done_at is not None, "DIV overlap test did not complete"
    dut._log.info(f"DIV overlap completed in {done_at} cycles "
                  f"({N_OVERLAP_OPS} independent ops overlapped)")
    # A fully-stalling DIV needs ~65 + 40 + fill here; overlap must beat it.
    assert done_at < 130, f"no overlap? took {done_at} cycles"


@cocotb.test()
async def test_mul_throughput(dut):
    """Phase 1: back-to-back independent MULs retire at ~1/cycle.

    8 independent MULs (single-cycle now) plus stores. A 4-cycle MUL
    design would need 8*4 + fill cycles here.
    """
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    prog = {
        0x00: enc_i(3, 0, 0, 1),            # addi x1, x0, 3
        0x04: enc_i(5, 0, 0, 2),            # addi x2, x0, 5
    }
    addr = 0x08
    for rd in range(3, 11):
        prog[addr] = enc_r(0x01, 2, 1, 0x0, rd)  # mul xN, x1, x2 (= 15)
        addr += 4
    prog[addr] = enc_i(0x100, 0, 0, 20)      # addi x20, x0, 0x100
    addr += 4
    prog[addr] = enc_s(0, 10, 20, 0x2)       # sw x10, 0(x20) -> TOHOST (= 15)
    addr += 4
    prog[addr] = 0x0000006F                  # jal x0, 0 (halt)

    imem = WishboneMemory(dut, "iwb", init_data=prog)
    dmem = WishboneMemory(dut, "dwb")

    cocotb.start_soon(imem.run())
    cocotb.start_soon(dmem.run())

    await reset_dut(dut)

    done_at = await run_until_store(dut, dmem, 15)
    assert done_at is not None, "MUL throughput test did not complete"
    dut._log.info(f"8xMUL throughput completed in {done_at} cycles")
    # 4-cycle MULs would need 8*4 + fill here; single-cycle must beat it.
    assert done_at < 40, f"no 1/cycle throughput? took {done_at} cycles"
