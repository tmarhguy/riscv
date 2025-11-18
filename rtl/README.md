# RTL Directory

This directory contains the synthesizable SystemVerilog source code for the IronCore RV32IM processor.

## Purpose
To provide a lint-clean, production-grade implementation of a 5-stage RISC-V core suitable for FPGA and ASIC flows.

## Key Files

| File | Stage/Function | Description |
|------|----------------|-------------|
| `ironcore_top.sv` | Top | Top-level module integrating all stages. |
| `ironcore_if.sv` | IF | Instruction Fetch, PC generation. |
| `ironcore_id.sv` | ID | Instruction Decode, Register Read. |
| `ironcore_ex.sv` | EX | ALU, Branch Compare, Mul/Div control. |
| `ironcore_mem.sv` | MEM | Memory Load/Store interface. |
| `ironcore_wb.sv` | WB | Writeback to register file. |
| `ironcore_hazard.sv` | HZ | Forwarding and Stall control logic. |
| `ironcore_csr.sv` | CSR | Control & Status Registers (M-mode). |
| `ironcore_alu.sv` | ALU | Arithmetic Logic Unit. |
| `ironcore_muldiv.sv` | MULDIV | Iterative Multiplier/Divider. |

## Architecture

The design follows a strict 5-stage pipeline:
**IF -> ID -> EX -> MEM -> WB**

*   **Signals**: All inter-stage signals are registered.
*   **Bypassing**: Full bypassing is implemented to resolve data hazards.
*   **Stalls**: Load-Use hazards induce a 1-cycle stall.

## Coding Standards

*   **Language**: SystemVerilog-2012.
*   **Style**:
    *   `always_ff @(posedge clk)` for sequential logic.
    *   `always_comb` for combinational logic.
    *   No implicit latches.
    *   `ironcore_pkg.sv` used for types, enums, and constants.
