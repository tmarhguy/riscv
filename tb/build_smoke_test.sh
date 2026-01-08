#!/bin/bash
# RV64IM Smoke Test Build Script

set -e

echo "=== RV64IM Smoke Test Build ==="

# Check for RISC-V toolchain
if ! command -v riscv64-unknown-elf-gcc &> /dev/null; then
    echo "ERROR: riscv64-unknown-elf-gcc not found"
    echo "Please install RISC-V toolchain for RV64"
    exit 1
fi

# Compile smoke test
echo "Compiling smoke_test_rv64.S..."
riscv64-unknown-elf-gcc \
    -march=rv64im \
    -mabi=lp64 \
    -nostdlib \
    -nostartfiles \
    -Ttext=0x00000000 \
    -o smoke_test_rv64.elf \
    smoke_test_rv64.S

# Generate binary
echo "Generating binary..."
riscv64-unknown-elf-objcopy \
    -O binary \
    smoke_test_rv64.elf \
    smoke_test_rv64.bin

# Generate hex dump for inspection
echo "Generating hex dump..."
riscv64-unknown-elf-objdump \
    -d \
    -M numeric \
    smoke_test_rv64.elf \
    > smoke_test_rv64.dump

# Generate memory hex file
echo "Generating memory hex file..."
hexdump -v -e '1/4 "%08x\n"' smoke_test_rv64.bin > smoke_test_rv64.hex

echo ""
echo "=== Build Complete ==="
echo "Files generated:"
echo "  - smoke_test_rv64.elf   (ELF executable)"
echo "  - smoke_test_rv64.bin   (Raw binary)"
echo "  - smoke_test_rv64.dump  (Disassembly)"
echo "  - smoke_test_rv64.hex   (Memory hex)"
echo ""
echo "To view disassembly:"
echo "  cat smoke_test_rv64.dump"
echo ""
echo "Next: Run simulation with Verilator"
