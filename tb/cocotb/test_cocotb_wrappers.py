"""
Cocotb test wrappers using cocotb-test for pytest integration
"""

import pytest
import os
from pathlib import Path
from cocotb_test.simulator import run

# Get paths
RTL_DIR = Path(__file__).parent.parent.parent / "rtl"
TB_DIR = Path(__file__).parent


def test_alu_basic():
    """Test ALU basic operations"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_alu.sv")
        ],
        toplevel="ironcore_alu",
        module="test_alu",
        simulator="verilator",
        work_dir=str(TB_DIR / "alu" / "sim_build"),
        extra_args=["--trace-fst", "--trace-structs", "-Wno-fatal", "--timing", "--coverage", f"-I{RTL_DIR / 'include'}"],
        testcase="test_alu_basic",
        pythonpath=[str(TB_DIR / "alu")]
    )


def test_alu_random():
    """Test ALU with random inputs"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_alu.sv")
        ],
        toplevel="ironcore_alu",
        module="test_alu",
        simulator="verilator",
        work_dir=str(TB_DIR / "alu" / "sim_build"),
        extra_args=["--trace-fst", "--trace-structs", "-Wno-fatal", "--timing", "--coverage", f"-I{RTL_DIR / 'include'}"],
        testcase="test_alu_random"
    )


def test_decoder_alu_ops():
    """Test decoder for ALU operations"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_decoder.sv")
        ],
        toplevel="ironcore_decoder",
        module="test_decoder",
        simulator="verilator",
        work_dir=str(TB_DIR / "decoder" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_decoder_alu_ops"
    )


def test_decoder_branches():
    """Test decoder for branch instructions"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_decoder.sv")
        ],
        toplevel="ironcore_decoder",
        module="test_decoder",
        simulator="verilator",
        work_dir=str(TB_DIR / "decoder" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_decoder_branches"
    )


def test_decoder_m_extension():
    """Test decoder for M extension instructions"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_decoder.sv")
        ],
        toplevel="ironcore_decoder",
        module="test_decoder",
        simulator="verilator",
        work_dir=str(TB_DIR / "decoder" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_decoder_m_extension"
    )


def test_decoder_illegal():
    """Test decoder illegal instruction detection"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_decoder.sv")
        ],
        toplevel="ironcore_decoder",
        module="test_decoder",
        simulator="verilator",
        work_dir=str(TB_DIR / "decoder" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_decoder_illegal"
    )


def test_decoder_random():
    """Test decoder with random instructions"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_decoder.sv")
        ],
        toplevel="ironcore_decoder",
        module="test_decoder",
        simulator="verilator",
        work_dir=str(TB_DIR / "decoder" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_decoder_random"
    )


def test_csr_rw():
    """Test CSR read/write"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_csr.sv")
        ],
        toplevel="ironcore_csr",
        module="test_csr",
        simulator="verilator",
        work_dir=str(TB_DIR / "csr" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_csr_rw"
    )


def test_trap_handling():
    """Test CSR trap handling"""
    run(
        verilog_sources=[
            str(RTL_DIR / "include" / "ironcore_pkg.sv"),
            str(RTL_DIR / "ironcore_csr.sv")
        ],
        toplevel="ironcore_csr",
        module="test_csr",
        simulator="verilator",
        work_dir=str(TB_DIR / "csr" / "sim_build"),
        extra_args=["--trace-fst", "-Wno-fatal", f"-I{RTL_DIR / 'include'}"],
        testcase="test_trap_handling"
    )
