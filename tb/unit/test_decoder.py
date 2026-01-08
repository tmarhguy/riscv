"""
Unit tests for IronCore Decoder
Tests instruction decoding and immediate generation
"""

import pytest


def sign_extend(value: int, bits: int) -> int:
    """Sign extend a value from 'bits' bits to 32 bits"""
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def decode_imm_i(instr: int) -> int:
    """Decode I-type immediate"""
    imm = (instr >> 20) & 0xFFF
    return sign_extend(imm, 12)


def decode_imm_s(instr: int) -> int:
    """Decode S-type immediate"""
    imm11_5 = (instr >> 25) & 0x7F
    imm4_0 = (instr >> 7) & 0x1F
    imm = (imm11_5 << 5) | imm4_0
    return sign_extend(imm, 12)


def decode_imm_b(instr: int) -> int:
    """Decode B-type immediate"""
    imm12 = (instr >> 31) & 0x1
    imm11 = (instr >> 7) & 0x1
    imm10_5 = (instr >> 25) & 0x3F
    imm4_1 = (instr >> 8) & 0xF
    imm = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
    return sign_extend(imm, 13)


def decode_imm_u(instr: int) -> int:
    """Decode U-type immediate"""
    return instr & 0xFFFFF000


def decode_imm_j(instr: int) -> int:
    """Decode J-type immediate"""
    imm20 = (instr >> 31) & 0x1
    imm19_12 = (instr >> 12) & 0xFF
    imm11 = (instr >> 20) & 0x1
    imm10_1 = (instr >> 21) & 0x3FF
    imm = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1)
    return sign_extend(imm, 21)


class TestImmediateDecoding:
    """Test immediate value decoding"""

    @pytest.mark.parametrize("instr,expected", [
        (0x00100093, 1),      # addi x1, x0, 1
        (0xFFF00093, -1),     # addi x1, x0, -1
        (0x7FF00093, 2047),   # addi x1, x0, 2047
        (0x80000093, -2048),  # addi x1, x0, -2048
    ])
    def test_i_type(self, instr, expected):
        result = decode_imm_i(instr)
        # Convert expected to unsigned 32-bit for comparison
        expected_u32 = expected & 0xFFFFFFFF
        result_u32 = result & 0xFFFFFFFF
        assert result_u32 == expected_u32

    @pytest.mark.parametrize("instr,expected", [
        (0x00112023, 0),      # sw x1, 0(x2)
        (0x00112223, 4),      # sw x1, 4(x2)
        (0xFE112E23, -4),     # sw x1, -4(x2)
    ])
    def test_s_type(self, instr, expected):
        result = decode_imm_s(instr)
        expected_u32 = expected & 0xFFFFFFFF
        result_u32 = result & 0xFFFFFFFF
        assert result_u32 == expected_u32

    @pytest.mark.parametrize("instr,expected", [
        (0x00208463, 8),      # beq x1, x2, +8
        (0xFE208EE3, -4),     # beq x1, x2, -4
    ])
    def test_b_type(self, instr, expected):
        result = decode_imm_b(instr)
        expected_u32 = expected & 0xFFFFFFFF
        result_u32 = result & 0xFFFFFFFF
        assert result_u32 == expected_u32

    @pytest.mark.parametrize("instr,expected", [
        (0x123450B7, 0x12345000),  # lui x1, 0x12345
        (0x000010B7, 0x00001000),  # lui x1, 1
        (0xFFFFF0B7, 0xFFFFF000),  # lui x1, 0xFFFFF
    ])
    def test_u_type(self, instr, expected):
        result = decode_imm_u(instr)
        assert result == expected

    @pytest.mark.parametrize("instr,expected", [
        (0x008000EF, 8),      # jal x1, +8
        (0xFFDFF0EF, -4),     # jal x1, -4
    ])
    def test_j_type(self, instr, expected):
        result = decode_imm_j(instr)
        expected_u32 = expected & 0xFFFFFFFF
        result_u32 = result & 0xFFFFFFFF
        assert result_u32 == expected_u32


class TestOpcodeDecoding:
    """Test opcode identification"""

    # Opcodes
    OP_LUI = 0b0110111
    OP_AUIPC = 0b0010111
    OP_JAL = 0b1101111
    OP_JALR = 0b1100111
    OP_BRANCH = 0b1100011
    OP_LOAD = 0b0000011
    OP_STORE = 0b0100011
    OP_OP_IMM = 0b0010011
    OP_OP = 0b0110011

    def extract_opcode(self, instr: int) -> int:
        return instr & 0x7F

    @pytest.mark.parametrize("instr,expected_op", [
        (0x123450B7, OP_LUI),      # lui
        (0x12345097, OP_AUIPC),    # auipc
        (0x008000EF, OP_JAL),      # jal
        (0x00008067, OP_JALR),     # jalr (ret)
        (0x00208463, OP_BRANCH),   # beq
        (0x00002083, OP_LOAD),     # lw
        (0x00112023, OP_STORE),    # sw
        (0x00100093, OP_OP_IMM),   # addi
        (0x002081B3, OP_OP),       # add
    ])
    def test_opcode_extraction(self, instr, expected_op):
        assert self.extract_opcode(instr) == expected_op


class TestRegisterDecoding:
    """Test register field extraction"""

    def extract_rd(self, instr: int) -> int:
        return (instr >> 7) & 0x1F

    def extract_rs1(self, instr: int) -> int:
        return (instr >> 15) & 0x1F

    def extract_rs2(self, instr: int) -> int:
        return (instr >> 20) & 0x1F

    @pytest.mark.parametrize("instr,rd,rs1,rs2", [
        (0x002081B3, 3, 1, 2),    # add x3, x1, x2
        (0x40208233, 4, 1, 2),    # sub x4, x1, x2
        (0x00000013, 0, 0, 0),    # nop (addi x0, x0, 0)
    ])
    def test_register_extraction(self, instr, rd, rs1, rs2):
        assert self.extract_rd(instr) == rd
        assert self.extract_rs1(instr) == rs1
        assert self.extract_rs2(instr) == rs2
