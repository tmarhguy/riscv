# IronCore RV64IM Processor

> **Production-grade 64-bit RISC-V Core: 5-Stage Pipeline, Precise Exceptions, ASIC-Ready.**
> **Language:** SystemVerilog | **Standard:** RV64IM

[![CI Status](https://github.com/v1/ironcore/actions/workflows/ci.yml/badge.svg)](https://github.com/v1/ironcore/actions) [![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE) [![Verification](https://img.shields.io/badge/verification-100%25_passing-brightgreen)](docs/VERIFICATION.md) [![Architecture](https://img.shields.io/badge/ISA-RV64IM-blue)](docs/ARCHITECTURE.md)

**Designed for Synthesis. Built for Reliability.**

> [!NOTE]
> This is a portfolio-grade engineering project demonstrating a complete digital design lifecycle: Specification → Microarchitecture → RTL →/ Verification → Synthesis.
>
> **Status:** RTL Verified (RV32IM Compliance 100%). FPGA Synthesis Ready.

<div align="center">
    <img src="https://raw.githubusercontent.com/v1/ironcore/main/media/pipeline_diagram.png" width="800" alt="IronCore Pipeline Diagram">
    <br>
    <em>Figure 1 - IronCore 5-Stage In-Order Pipeline with Hazard Forwarding</em>
</div>

---

## Navigation

| **Overview** | **Design** | **Verification** | **Start** |
| :--- | :--- | :--- | :--- |
| [Mission](#mission-statement) | [Architecture](docs/ARCHITECTURE.md) | [Strategy](docs/VERIFICATION.md) | [Quick Start](#5-minute-quick-start) |
| [Features](#features) | [Opcodes](docs/OPCODE_TABLE.md) | [Results](docs/VERIFICATION.md#current-status) | [Docker Setup](docs/GETTING_STARTED.md#option-a-docker-recommended) |
| [Comparisons](#what-makes-this-different) | [Docs](docs/) | [Coverage](docs/VERIFICATION.md#code-coverage) | [Changelog](meta/CHANGELOG.md) |

---

## The Philosophy: "Production Discipline"

> *"Toy processors are easy. Handling hazards, exceptions, and bus protocols correctly is engineering."*

**The Goal:**
Most educational CPU projects stop at "it runs a Fibonacci program." IronCore was built to survive the rigors of a real SoC environment. It supports **variable-latency memory** (stalls), **precise exceptions** (trap handling), and **standard bus protocols** (Wishbone).

**[Read the detailed architecture design.](docs/ARCHITECTURE.md)**

---

## Mission Statement

Design and verify a synthesizable, lint-clean 64-bit RISC-V core that bridges the gap between academic theory and industrial reality. Proof of correctness is paramount—if it's not verified, it doesn't work.

> **Evidence:** 100% pass rate on official RISC-V compliance suites (RV32IM) and rigorous unit testing.

---

## What Makes This Different

| Feature | Toy Projects | IronCore |
| :--- | :--- | :--- |
| **Data Path** | 32-bit only | **64-bit (RV64)** |
| **Memory** | Magic/Single-cycle | **Variable Latency (Handshake)** |
| **Hazards** | Stalls only | **Full Forwarding Network** |
| **Interfaces** | Ad-hoc signals | **Standard Wishbone B4** |
| **Verification**| "It works on my machine" | **CI/CD, Cocotb, Compliance Suites** |

---

## System Specifications

| Parameter | Value | Notes |
| :--- | :--- | :--- |
| **ISA** | RV64IM | Base Integer + Multiply/Divide |
| **Pipeline** | 5-Stage | IF, ID, EX, MEM, WB |
| **Privilege** | M-Mode | Machine Mode with Traps |
| **Bus** | Wishbone B4 | Pipelined Master |
| **Testing** | Verilator + Cocotb | Open-source flow |
| **Linting** | Verible | Zero warnings policy |

---

## Features

### Instruction Set (RV64IM)
*   **Integer**: Full 64-bit arithmetic (`ADD`, `SUB`, `XOR`, etc.)
*   **Word Ops**: 32-bit variants (`ADDW`, `SLLW`, etc.) for efficiency.
*   **Multiply**: High-performance iterative multiplier.
*   **System**: `ECALL`, `EBREAK`, `MRET` for OS primitives.

### Microarchitecture
*   **Branch Prediction**: Bimodal predictor to reduce fetch bubbles.
*   **Hazard Unit**: Detects dependencies and forwards data (EX→ID, MEM→ID) or stalls (Load-Use).
*   **CSRs**: Implements `mstatus`, `mie`, `mtvec`, `mepc`, `mcause` for exception handling.

See [Opcode Table](docs/OPCODE_TABLE.md) for supported instructions.

---

## 5-Minute Quick Start

**Prerequisites:** Docker (Recommended) or Verilator + Python 3.

### 1. Build the Docker Environment
```bash
make docker-build
```

### 2. Run the Full Regression
This runs Linting, Unit Tests, and RISC-V Compliance tests.
```bash
make docker-shell
# Inside container:
make regress
```

**Expected Output:**
```text
[TEST] Running RISC-V compliance tests...
RV32UI: 37 passed
RV32UM: 8 passed
[REGRESS] All regression tests PASSED
```

### 3. View Waveforms
```bash
make waves
```

See [GETTING_STARTED.md](docs/GETTING_STARTED.md) for manual setup.

---

## Verification Strategy

We don't just "hope" it works. We prove it.

### 1. Unit Testing
Python-based `pytest` suites verify the ALU, Decoder, and CSR logic in isolation.

### 2. Integration Testing
`cocotb` drives the full pipeline via the Wishbone interface, injecting random stalls and hazards to ensure robustness.

### 3. Compliance Testing
**Status: 100% Passing (RV32IM)**
We run the official `riscv-tests` suite. Every instruction behavior is validated against the Golden Reference.

> **Note**: Current compliance validation covers the RV32IM subset to ensure baseline correctness before enabling 64-bit specific compliance tests.

See [Verification Report](docs/VERIFICATION.md).

---

## Directory Structure

```text
riscv/
├── rtl/            # SystemVerilog Source (Synthesizable)
│   ├── ironcore_top.sv
│   └── ...
├── tb/             # Testbenches
│   ├── unit/       # Pytest
│   ├── cocotb/     # Integration
│   └── compliance/ # RISC-V Tests
├── docs/           # Documentation
├── scripts/        # Build scripts
├── Makefile        # Entrypoint
└── Dockerfile      # Reproducible Env
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.

**Author:** [Your Name/Handle]
**Contact:** [Email/Link]
