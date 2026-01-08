#!/bin/bash
# IronCore Test Runner
# Builds and runs verification tests

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
TEST_DIR="$ROOT_DIR/tb/asm"
SIM="$BUILD_DIR/obj_dir/ironcore_sim"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "IronCore Verification Test Suite"
echo "=========================================="

# Check for RISC-V toolchain
if ! command -v riscv-none-elf-gcc &> /dev/null; then
    if command -v riscv32-unknown-elf-gcc &> /dev/null; then
        export CROSS_PREFIX=riscv32-unknown-elf-
    elif command -v riscv64-unknown-elf-gcc &> /dev/null; then
        export CROSS_PREFIX=riscv64-unknown-elf-
    else
        echo -e "${RED}Error: RISC-V toolchain not found${NC}"
        echo "Please install riscv-none-elf-gcc, riscv32-unknown-elf-gcc, or riscv64-unknown-elf-gcc"
        exit 1
    fi
else
    # Explicitly set if found, just in case
    export CROSS_PREFIX=riscv-none-elf-
fi

# Build simulator using project Makefile
echo "Building simulator..."
# Skip verible lint as it's not installed in this environment
make -C "$ROOT_DIR" lint-verilator
# Ensure SIM binary exists (built by verilator command in Makefile or implicit)
# The root Makefile doesn't have explicit 'sim' target but 'lint' and 'verilator' flags.
# We call the verilator command manually or via a new target if we added one. 
# Re-using the direct verilator call consistent with Makefile settings:
cd "$ROOT_DIR"
rm -rf build/obj_dir
verilator --cc --exe --build -j 0 --trace-fst --assert \
    -Wall -Wno-fatal -Wno-IMPORTSTAR --timing --coverage \
    --top-module ironcore_top \
    -Irtl/include \
    rtl/include/ironcore_pkg.sv \
    rtl/ironcore_alu.sv \
    rtl/ironcore_muldiv.sv \
    rtl/ironcore_decoder.sv \
    rtl/ironcore_if.sv \
    rtl/ironcore_id.sv \
    rtl/ironcore_ex.sv \
    rtl/ironcore_mem.sv \
    rtl/ironcore_bp.sv \
    rtl/ironcore_hazard.sv \
    rtl/ironcore_csr.sv \
    rtl/ironcore_top.sv \
    tb/verilator/tb_ironcore.cpp \
    -o ironcore_sim \
    --Mdir build/obj_dir > /dev/null

if [ ! -f "$SIM" ]; then
    echo -e "${RED}Error: Simulator build failed${NC}"
    exit 1
fi

# Build assembly tests
echo ""
echo "Building assembly tests..."
make -C "$TEST_DIR" all

# Run built-in Test Suites (C++ driven)
echo ""
echo "Running Built-in Suites..."
if "$SIM" --suite all; then
    echo -e "${GREEN}Built-in Suites: PASS${NC}"
else
    echo -e "${RED}Built-in Suites: FAIL${NC}"
    exit 1
fi

# Run Legacy Assembly Tests (File-based)
echo ""
echo "Running Legacy Assembly Tests..."
TESTS="test_alu test_forwarding test_stalls test_branches test_jumps test_load_store test_muldiv test_traps"
PASSED=0
FAILED=0
TOTAL=0

mkdir -p "$ROOT_DIR/waves"

for test in $TESTS; do
    TOTAL=$((TOTAL + 1))
    TEST_BIN="$TEST_DIR/build/${test}.bin"

    if [ ! -f "$TEST_BIN" ]; then
        echo -e "${YELLOW}SKIP${NC}: $test (not built)"
        continue
    fi

    # Run test
    if "$SIM" "$TEST_BIN" > /dev/null; then
        echo -e "${GREEN}PASS${NC}: $test"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $test"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=========================================="
echo "Results: $PASSED/$TOTAL legacy tests passed"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
