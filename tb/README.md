# Verification Directory (tb)

This directory contains the verification infrastructure for IronCore.

## Strategy

The verification strategy is split into three tiers:

1.  **Unit Tests** (`tb/unit/`):
    *   **Goal**: low-level functional correctness of submodules (ALU, Decoder).
    *   **Tool**: Pytest (Python).
    *   **Command**: `make unit`

2.  **Integration Tests** (`tb/cocotb/`):
    *   **Goal**: Top-level processor verification running assembly programs.
    *   **Tool**: Cocotb + Verilator.
    *   **Command**: `make cocotb`

3.  **Compliance Tests** (`tb/compliance/`):
    *   **Goal**: Architectural compliance against the RISC-V spec.
    *   **Tool**: RISC-V Arch Tests + Verilator.
    *   **Command**: `make compliance`

## Directory Structure

*   `unit/`: Python scripts for testing standalone combinatorial modules.
*   `cocotb/`: System-level testbench using Cocotb. Includes `Makefile` for Cocotb runners.
*   `compliance/`: Submodule/integration for the official RISC-V compliance suite.

## How to Run

Run the full regression suite from the project root:
```bash
make regress
```
This runs Lint -> Unit -> Cocotb -> Compliance.
