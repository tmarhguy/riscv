"""
Unit tests for IronCore ALU
"""

import pytest


# ALU operation encoding (matches ironcore_pkg.sv)
class AluOp:
    ADD = 0b0000
    SUB = 0b0001
    SLL = 0b0010
    SLT = 0b0011
    SLTU = 0b0100
    XOR = 0b0101
    SRL = 0b0110
    SRA = 0b0111
    OR = 0b1000
    AND = 0b1001
    PASS_B = 0b1010


def alu_model(op: int, a: int, b: int) -> int:
    """Reference ALU model"""
    # Mask to 32 bits
    a = a & 0xFFFFFFFF
    b = b & 0xFFFFFFFF

    if op == AluOp.ADD:
        result = (a + b) & 0xFFFFFFFF
    elif op == AluOp.SUB:
        result = (a - b) & 0xFFFFFFFF
    elif op == AluOp.SLL:
        shamt = b & 0x1F
        result = (a << shamt) & 0xFFFFFFFF
    elif op == AluOp.SLT:
        # Signed comparison
        a_signed = a if a < 0x80000000 else a - 0x100000000
        b_signed = b if b < 0x80000000 else b - 0x100000000
        result = 1 if a_signed < b_signed else 0
    elif op == AluOp.SLTU:
        result = 1 if a < b else 0
    elif op == AluOp.XOR:
        result = a ^ b
    elif op == AluOp.SRL:
        shamt = b & 0x1F
        result = a >> shamt
    elif op == AluOp.SRA:
        shamt = b & 0x1F
        if a & 0x80000000:  # Negative
            # Sign extend
            result = (a >> shamt) | (0xFFFFFFFF << (32 - shamt)) & 0xFFFFFFFF
        else:
            result = a >> shamt
    elif op == AluOp.OR:
        result = a | b
    elif op == AluOp.AND:
        result = a & b
    elif op == AluOp.PASS_B:
        result = b
    else:
        result = 0

    return result


class TestAluModel:
    """Test the ALU reference model"""

    @pytest.mark.parametrize("a,b,expected", [
        (0, 0, 0),
        (1, 2, 3),
        (0xFFFFFFFF, 1, 0),  # Overflow
        (0x7FFFFFFF, 1, 0x80000000),
    ])
    def test_add(self, a, b, expected):
        assert alu_model(AluOp.ADD, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (5, 3, 2),
        (0, 1, 0xFFFFFFFF),  # Underflow
        (0x80000000, 1, 0x7FFFFFFF),
    ])
    def test_sub(self, a, b, expected):
        assert alu_model(AluOp.SUB, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (1, 0, 1),
        (1, 1, 2),
        (1, 31, 0x80000000),
        (0xFFFFFFFF, 1, 0xFFFFFFFE),
    ])
    def test_sll(self, a, b, expected):
        assert alu_model(AluOp.SLL, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (5, 10, 1),   # 5 < 10
        (10, 5, 0),   # 10 >= 5
        (0xFFFFFFFF, 0, 1),  # -1 < 0 (signed)
        (0x80000000, 0x7FFFFFFF, 1),  # MIN < MAX
    ])
    def test_slt(self, a, b, expected):
        assert alu_model(AluOp.SLT, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (5, 10, 1),
        (10, 5, 0),
        (0xFFFFFFFF, 0, 0),  # 0xFFFFFFFF > 0 (unsigned)
    ])
    def test_sltu(self, a, b, expected):
        assert alu_model(AluOp.SLTU, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (0xF0F0F0F0, 0x0F0F0F0F, 0xFFFFFFFF),
        (0xAAAAAAAA, 0x55555555, 0xFFFFFFFF),
        (0, 0, 0),
    ])
    def test_xor(self, a, b, expected):
        assert alu_model(AluOp.XOR, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (0x80000000, 1, 0x40000000),
        (0xFF, 4, 0x0F),
        (0xFFFFFFFF, 31, 1),
    ])
    def test_srl(self, a, b, expected):
        assert alu_model(AluOp.SRL, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (0x80000000, 1, 0xC0000000),  # Sign extends
        (0x7FFFFFFF, 1, 0x3FFFFFFF),  # No sign extension
        (0x80000000, 31, 0xFFFFFFFF),
    ])
    def test_sra(self, a, b, expected):
        assert alu_model(AluOp.SRA, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (0xF0F0F0F0, 0x0F0F0F0F, 0xFFFFFFFF),
        (0xF0000000, 0x0000000F, 0xF000000F),
    ])
    def test_or(self, a, b, expected):
        assert alu_model(AluOp.OR, a, b) == expected

    @pytest.mark.parametrize("a,b,expected", [
        (0xF0F0F0F0, 0x0F0F0F0F, 0),
        (0xFFFFFFFF, 0xF0F0F0F0, 0xF0F0F0F0),
    ])
    def test_and(self, a, b, expected):
        assert alu_model(AluOp.AND, a, b) == expected

    def test_pass_b(self):
        assert alu_model(AluOp.PASS_B, 0x12345678, 0xDEADBEEF) == 0xDEADBEEF
