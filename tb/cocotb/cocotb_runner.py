"""riscv64xO3 cocotb runner (cocotb 2.x, pytest-based).

Replaces the legacy cocotb-config Makefiles (one per test dir), which only
work with cocotb 1.x. Each pytest test below builds one DUT with Verilator
and runs its test module::

    pytest tb/cocotb/cocotb_runner.py          # everything
    pytest tb/cocotb/cocotb_runner.py -m smoke # fast subset (alu)

Build trees live under build/cocotb/<dut> so Verilator incrementally
rebuilds only on RTL change.
"""

import pathlib

import pytest
from cocotb_tools.runner import get_runner

ROOT = pathlib.Path(__file__).resolve().parents[2]
RTL = ROOT / "rtl"
TB = ROOT / "tb" / "cocotb"
BUILD = ROOT / "build" / "cocotb"

FULL_RTL = [
    "include/rv64xo3_pkg.sv",
    "rv64xo3_alu.sv",
    "rv64xo3_muldiv.sv",
    "rv64xo3_decoder.sv",
    "rv64xo3_if.sv",
    "rv64xo3_id.sv",
    "rv64xo3_ex.sv",
    "rv64xo3_mem.sv",
    "rv64xo3_bp.sv",
    "rv64xo3_hazard.sv",
    "rv64xo3_hazard_sva.sv",
    "rv64xo3_csr.sv",
    "issue/rv64xo3_rename.sv",
    "issue/rv64xo3_rs.sv",
    "memory/rv64xo3_lsq.sv",
    "commit/rv64xo3_rob.sv",
    "rv64xo3_top.sv",
]

# name -> (rtl sources, toplevel, test dirs holding the test modules,
#           test modules, optional testcase filter)
CONFIGS = {
    "bp": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_bp.sv"],
        "rv64xo3_bp", [TB / "bp"], ["test_bp"], [],
    ),
    "alu": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_alu.sv"],
        "rv64xo3_alu",
        [TB / "alu"],
        ["test_alu"],
        [],
    ),
    "decoder": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_decoder.sv"],
        "rv64xo3_decoder",
        [TB / "decoder"],
        ["test_decoder"],
        [],
    ),
    "csr": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_csr.sv"],
        "rv64xo3_csr",
        [TB / "csr"],
        ["test_csr"],
        [],
    ),
    "mem": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_mem.sv"],
        "rv64xo3_mem",
        [TB / "mem"],
        ["test_mem"],
        [],
    ),
    "muldiv": (
        ["include/rv64xo3_pkg.sv", "rv64xo3_muldiv.sv"],
        "rv64xo3_muldiv",
        [TB / "muldiv"],
        ["test_muldiv"],
        [],
    ),
    "axi_imem": (
        [
            "include/rv64xo3_pkg.sv",
            "rv64xo3_axi4lite_imem.sv",
            "rv64xo3_axi4lite_dmem.sv",
        ],
        "rv64xo3_axi4lite_imem",
        [TB / "axi4lite"],
        ["test_axi_bridge"],
        ["test_imem_basic_read"],
    ),
    "axi_dmem": (
        [
            "include/rv64xo3_pkg.sv",
            "rv64xo3_axi4lite_imem.sv",
            "rv64xo3_axi4lite_dmem.sv",
        ],
        "rv64xo3_axi4lite_dmem",
        [TB / "axi4lite"],
        ["test_axi_bridge"],
        ["test_dmem_write_read", "test_dmem_byte_enables"],
    ),
    "top": (
        FULL_RTL,
        "rv64xo3_top",
        [TB, TB],
        ["test_rv64xo3", "test_hello"],
        [],
    ),
}


def _run(name, exclude=()):
    sources, toplevel, test_dirs, modules, cases = CONFIGS[name]
    build_dir = BUILD / name
    runner = get_runner("verilator")
    runner.build(
        sources=[RTL / s for s in sources],
        hdl_toplevel=toplevel,
        build_dir=str(build_dir),
        build_args=[
            "--timing",
            "-Wno-fatal",
            "-Wno-UNUSEDSIGNAL",
            "-I" + str(RTL / "include"),
        ],
    )
    ran_any = False
    for test_dir, module in zip(test_dirs, modules):
        if module in exclude:
            continue
        ran_any = True
        runner.test(
            hdl_toplevel=toplevel,
            test_module=module,
            test_dir=str(test_dir),
            build_dir=str(build_dir),
            testcase=",".join(cases) if cases else None,
        )
    if not ran_any:
        pytest.skip("no test modules selected")


@pytest.mark.smoke
def test_alu():
    _run("alu")


def test_decoder():
    _run("decoder")


def test_csr():
    _run("csr")


def test_mem():
    _run("mem")


def test_muldiv():
    _run("muldiv")


def test_axi():
    _run("axi_imem")
    _run("axi_dmem")


def test_top():
    # test_hello needs sw/build/hello.vmem (riscv toolchain); run the
    # hand-encoded core tests regardless, skip hello if unbuilt.
    exclude = (
        []
        if (ROOT / "sw" / "build" / "hello.vmem").exists()
        else ["test_hello"]
    )
    if exclude:
        print("sw/build/hello.vmem missing: skipping test_hello (build with bare-metal toolchain via `make -C sw`)")
    _run("top", exclude=exclude)


def test_bp():
    _run("bp")
