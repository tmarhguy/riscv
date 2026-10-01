# RTL Directory

Synthesizable SystemVerilog for the riscv64xO3 RV64IMAC out-of-order core.

## Purpose

Lint-clean, 2-wide superscalar Tomasulo implementation (in progress) with a
working scalar 5-stage path underneath. Suitable for FPGA and ASIC flows.

## Key Files

| File | Stage/Function | Description |
|------|----------------|-------------|
| `rv64xo3_top.sv` | Top | Scalar 5-stage core; OoO issue/commit landing |
| `rv64xo3_top_axi.sv` | Top/AXI | AXI4-Lite system wrapper |
| `rv64xo3_if.sv` | IF | Fetch, PC generation |
| `rv64xo3_id.sv` | ID | Decode, register read |
| `rv64xo3_ex.sv` | EX | ALU, branch compare, mul/div control |
| `rv64xo3_mem.sv` | MEM | Load/store interface |
| `rv64xo3_hazard.sv` | HZ | Forwarding and stall control |
| `rv64xo3_csr.sv` | CSR | M-mode CSRs and traps |
| `rv64xo3_alu.sv` | ALU | 64-bit ALU + W-ops |
| `rv64xo3_muldiv.sv` | MULDIV | Multiplier/divider (pipelining in progress) |
| `issue/rv64xo3_rename.sv` | Rename | Arch -> phys map (scaffold) |
| `issue/rv64xo3_rs.sv` | Issue | Reservation stations (scaffold) |
| `memory/rv64xo3_lsq.sv` | MEM | Load/store queue (scaffold) |
| `commit/rv64xo3_rob.sv` | Commit | Reorder buffer (scaffold) |

## Architecture

Scalar path: **IF -> ID -> EX -> MEM -> WB** with forwarding + load-use stall.
OoO target: **Fetch 2-wide -> Rename/Dispatch -> RS/Tomasulo -> LSQ/MEM ->
ROB commit**. See `docs/index.adoc` ch. 2-3 (RTL wins on conflict).

## Coding Standards

- SystemVerilog-2012, `always_ff` / `always_comb`, no latches.
- Types and params from `include/rv64xo3_pkg.sv`.
- Zero Verible + Verilator warnings.
