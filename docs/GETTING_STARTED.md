# Getting Started with IronCore

## Prerequisites

You can develop and simulate IronCore either using **Docker** (recommended) or by installing tools **locally**.

### Option A: Docker (Recommended)
This approach guarantees the correct tool versions and environment.

1.  **Install Docker Desktop** or Docker Engine.
2.  **Build the container**:
    ```bash
    make docker-build
    ```
3.  **Enter the development shell**:
    ```bash
    make docker-shell
    ```

### Option B: Local Installation
If you prefer running directly on your host machine (Linux/macOS), install the following:

*   **Verilator** (v4.200+)
    *   macOS: `brew install verilator`
    *   Ubuntu: `apt install verilator`
*   **Python 3.8+**
*   **Python Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
*   **RISC-V Toolchain**:
    *   `riscv64-unknown-elf-gcc` must be in your PATH.

---

## Building and Testing

Everything is driven by the `Makefile` in the root directory.

### 1. Linting
Check code quality and syntax.
```bash
make lint
```

### 2. Unit & Integration Tests
Run the Python-based test suite.
```bash
make unit       # Module-level tests
make cocotb     # Full pipeline integration tests
```

### 3. Compliance Tests
Run the official specific RISC-V architectural tests.
```bash
make compliance
```

### 4. Full Regression
Run **all** of the above to ensure the core is clean and correct.
```bash
make regress
```

---

## Simulation & Debugging

### Viewing Waveforms
By default, simulations generate `.fst` waveform files in the `waves/` directory.

To view the waveform of the last run:
```bash
make waves
```
*Note: This requires GTKWave to be installed on your host machine.*

### Directory Structure
*   `build/`: Compilation artifacts and logs.
*   `waves/`: Generated waveform files.
*   `tb/`: Testbench sources.
*   `rtl/`: Processor source code.
