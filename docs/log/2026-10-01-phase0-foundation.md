# Phase 0 foundation: build, compliance, and scalar correctness

Date: 2026-10-01. Local run (Apple Silicon, Verilator 5.052, xpack
riscv-none-elf-gcc 13.2.0). riscv-tests @ 7af6beb (submodule).

## Baseline (all green)

* `make lint` — Verible skipped (not installed locally), Verilator clean.
* `make unit` — 58 passed.
* `make cocotb` (new cocotb 2.x pytest runner) — 7 passed
  (alu, decoder, csr, mem, muldiv, axi imem+dmem, top).
* `make cocotb-smoke` — alu subset passes.
* `make compliance` (RV64 default) — RV64UI 54/54, RV64UM 13/13,
  RV64MI 15/15 (includes ma_addr, ma_fetch, misaligned family, sbreak).
* `make compliance-rv32` (legacy) — RV32UI 37/37, RV64UM 8/8.
* C++ harness suites — 15/15. Legacy asm (`scripts/run_tests.sh`) — 8/8.

## What was fixed to get here

* `make sim` canonical simulator target; `run_tests.sh` deduplicated.
* Compliance default switched to RV64 (`Makefile.rv64`); RV32 kept as
  `compliance-rv32`; riscv-tests vendored as submodule with env guards.
* C++ harness: base-relative test writes, per-test `--tohost` (address
  moves with test size), unified I/D memory (fence.i self-modifying
  code), unhandled traps no longer report PASS.
* RTL: muldiv operand latching (forwarding-mux drift) + REMUW div-by-zero;
  `misa` (MXL=2, I+M only), `sstatus`/`sscratch`/`mscratch`, CSR
  immediate (`zimm`) write path; load-use stall must not flush a load
  while MEM is frozen; faulting MEM ops must not retire (precise traps);
  fetch-misaligned trap + `sret`; `fence`/`fence.i` as NOPs; hardware
  misaligned-access splitting (no more traps for data misalignment).
* Legacy asm: linked at 0x80000000 (was 0x0, breaking `la`), test data
  moved clear of test code (stores clobbered code), RV32-era constant
  assumptions fixed for RV64 (alu tests 9/18/19, muldiv test 18).
* cocotb migrated to 2.x (`tb/cocotb/cocotb_runner.py`); dead
  cocotb-config Makefiles removed; unit tests updated to the compliant
  `mstatus` contract (hardwired SXL/UXL=2).

## Known gaps (not fixed)

* `pmpaddr` (no PMP unit), C/A extensions, caches, FPGA/ASIC beyond
  feasibility smoke. See ch. 9.
