"""Independent binutils expansion oracle and reserved encoding checks."""
import json
from pathlib import Path
import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_expansion(dut):
    vectors = json.loads(Path(__file__).with_name('vectors.json').read_text())
    for name, compressed, expanded in vectors:
        dut.instr_i.value = int.from_bytes(bytes.fromhex(compressed), 'little')
        await Timer(1, unit='ns')
        assert int(dut.illegal_o.value) == 0, name
        assert int(dut.instr_o.value) == int.from_bytes(bytes.fromhex(expanded), 'little'), name


@cocotb.test()
async def test_reserved(dut):
    # Zero ADDI4SPN, ADDIW x0, zero LUI/ADDI16SP, JR x0, LWSP/LDSP x0,
    # reserved word ALU encodings, unsupported FP and non-compressed inputs.
    for value in (0, 0x2001, 0x6001, 0x6101, 0x8002, 0x4002, 0x6002,
                  0x9c41, 0x9c61, 0x2000, 0xa000, 0x2002, 0xa002, 0xffff):
        dut.instr_i.value = value
        await Timer(1, unit='ns')
        assert int(dut.illegal_o.value) == 1, hex(value)
        assert int(dut.instr_o.value) == 0
