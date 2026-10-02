# riscv64xO3 RV64IMAC OoO Processor - Build System
# Canonical entrypoint for all project operations

.PHONY: all clean lint format sim unit cocotb compliance compliance-rv32 cpp-suite regress synth help
.PHONY: sw docker-build docker-ci-build docker-shell waves check-docs docs docs-clean docs-open asic-feas

# Configuration
TOPLEVEL := rv64xo3_top
RTL_DIR := rtl
TB_DIR := tb
SW_DIR := sw
BUILD_DIR := build
WAVE_DIR := waves

# Tool configuration
VERILATOR := verilator
VERIBLE_LINT := verible-verilog-lint
VERIBLE_FMT := verible-verilog-format
PYTHON := python3
PYTEST := $(PYTHON) -m pytest

# RTL sources (order matters for dependencies)
RTL_SRCS := \
	$(RTL_DIR)/include/rv64xo3_pkg.sv \
	$(RTL_DIR)/rv64xo3_alu.sv \
	$(RTL_DIR)/rv64xo3_muldiv.sv \
	$(RTL_DIR)/rv64xo3_decoder.sv \
	$(RTL_DIR)/rv64xo3_if.sv \
	$(RTL_DIR)/rv64xo3_id.sv \
	$(RTL_DIR)/rv64xo3_ex.sv \
	$(RTL_DIR)/rv64xo3_mem.sv \
	$(RTL_DIR)/rv64xo3_bp.sv \
	$(RTL_DIR)/rv64xo3_hazard.sv \
	$(RTL_DIR)/rv64xo3_hazard_sva.sv \
	$(RTL_DIR)/rv64xo3_csr.sv \
	$(RTL_DIR)/issue/rv64xo3_rename.sv \
	$(RTL_DIR)/issue/rv64xo3_rs.sv \
	$(RTL_DIR)/memory/rv64xo3_lsq.sv \
	$(RTL_DIR)/commit/rv64xo3_rob.sv \
	$(RTL_DIR)/rv64xo3_top.sv
RTL_INCS := $(RTL_DIR)/include

# Simulator binary (Verilator C++ harness in tb/verilator/).
# Canonical build rule: compliance suites and scripts/run_tests.sh use this.
# Do not duplicate the verilator invocation elsewhere.
SIM := $(BUILD_DIR)/obj_dir/rv64xo3_sim
SIM_TB := $(TB_DIR)/verilator/tb_rv64xo3.cpp
SIM_FLAGS := \
	--cc \
	--exe \
	--build \
	-j 0 \
	--trace-fst \
	--assert \
	-Wall \
	-Wno-fatal \
	-Wno-IMPORTSTAR \
	--timing \
	--coverage \
	--top-module $(TOPLEVEL) \
	-I$(RTL_INCS)

# Verilator FST tracing needs lz4. On Apple Silicon Homebrew installs it
# outside the default search path, so point Verilator's C++ build at it.
ifeq ($(shell uname),Darwin)
  BREW_PREFIX := $(shell brew --prefix 2>/dev/null)
  ifneq ($(BREW_PREFIX),)
    SIM_FLAGS += -CFLAGS -I$(BREW_PREFIX)/include -LDFLAGS -L$(BREW_PREFIX)/lib
  endif
endif

# Verilator lint-only flags
# UNUSEDPARAM waived: OoO params (ROB_SZ, PRF_SZ, ...) are API until wired in.
VERILATOR_LINT_FLAGS := \
	--lint-only \
	-Wall \
	-Wno-UNUSEDSIGNAL \
	-Wno-UNUSEDPARAM \
	-Wno-IMPORTSTAR \
	--top-module rv64xo3_top \
	-I$(RTL_INCS)

# Verible lint rules configuration
VERIBLE_LINT_RULES := \
	-rules=-line-length

#------------------------------------------------------------------------------
# Default target
#------------------------------------------------------------------------------
all: lint unit

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------
help:
	@echo "riscv64xO3 RV64IMAC OoO Processor - Build Targets"
	@echo "=========================================="
	@echo ""
	@echo "Quality Gates:"
	@echo "  make lint       - Run Verible + Verilator linting"
	@echo "  make format     - Format RTL with Verible"
	@echo "  make check-docs - Run docs guardrails"
	@echo ""
	@echo "Testing:"
	@echo "  make sim        - Build Verilator simulator binary"
	@echo "  make unit       - Run unit tests"
	@echo "  make cocotb     - Run cocotb integration tests"
	@echo "  make compliance - Run RISC-V compliance tests (RV64)"
	@echo "  make compliance-rv32 - Run legacy RV32 compliance baseline"
	@echo "  make regress    - Full regression (lint + all tests)"
	@echo ""
	@echo "Synthesis:"
	@echo "  make synth      - Run synthesis (Yosys)"
	@echo "  make asic-feas  - OpenLane feasibility (see asic/)"
	@echo ""
	@echo "Docs:"
	@echo "  make docs       - Build AsciiDoc manual to build/docs"
	@echo "  make docs-clean - Remove built manual"
	@echo "  make docs-open  - Serve built manual locally"
	@echo ""
	@echo "Development:"
	@echo "  make waves      - Open waveform viewer"
	@echo "  make clean      - Clean build artifacts"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build - Build development container"
	@echo "  make docker-shell - Launch interactive shell in container"

#------------------------------------------------------------------------------
# Linting
#------------------------------------------------------------------------------
lint: lint-verible lint-verilator
	@echo "[LINT] All lint checks passed"

lint-verible:
	@echo "[LINT] Running Verible lint..."
	@if command -v $(VERIBLE_LINT) >/dev/null 2>&1; then \
		$(VERIBLE_LINT) $(VERIBLE_LINT_RULES) $(RTL_SRCS) || (echo "[LINT] Verible lint failed" && exit 1); \
	else \
		echo "[LINT] WARNING: Verible not found. Install from:"; \
		echo "  https://github.com/chipsalliance/verible/releases"; \
		echo "  Or run: make docker-shell"; \
		echo "[LINT] Skipping Verible lint..."; \
	fi

lint-verilator:
	@echo "[LINT] Running Verilator lint..."
	@if command -v $(VERILATOR) >/dev/null 2>&1; then \
		$(VERILATOR) $(VERILATOR_LINT_FLAGS) $(RTL_SRCS) || (echo "[LINT] Verilator lint failed" && exit 1); \
	else \
		echo "[LINT] ERROR: Verilator not found. Install with:"; \
		echo "  brew install verilator"; \
		echo "  Or run: make docker-shell"; \
		exit 1; \
	fi

#------------------------------------------------------------------------------
# Formatting
#------------------------------------------------------------------------------
format:
	@echo "[FORMAT] Formatting RTL with Verible..."
	@$(VERIBLE_FMT) --inplace $(RTL_SRCS)
	@echo "[FORMAT] Done"

#------------------------------------------------------------------------------
# Simulator (Verilator C++ harness)
#------------------------------------------------------------------------------
sim: $(SIM)

$(SIM): $(RTL_SRCS) $(SIM_TB) | $(BUILD_DIR)
	@echo "[SIM] Building Verilator simulator..."
	$(VERILATOR) $(SIM_FLAGS) $(RTL_SRCS) $(SIM_TB) -o rv64xo3_sim --Mdir $(BUILD_DIR)/obj_dir
	@echo "[SIM] Built $(SIM)"

#------------------------------------------------------------------------------
# Unit Tests
#------------------------------------------------------------------------------
unit: $(BUILD_DIR)
	@echo "[TEST] Running unit tests..."
	@$(PYTEST) $(TB_DIR)/unit -v --tb=short --junitxml=$(BUILD_DIR)/unit-results.xml

#------------------------------------------------------------------------------
# Software (needs a bare-metal RISC-V toolchain in PATH; skipped by tests
# that can run without it)
#------------------------------------------------------------------------------
sw:
	@echo "[SW] Building hello world..."
	@$(MAKE) -C $(SW_DIR)

#------------------------------------------------------------------------------
# Cocotb Integration Tests (cocotb 2.x pytest runner)
#------------------------------------------------------------------------------
cocotb: $(BUILD_DIR)
	@echo "[TEST] Running cocotb tests..."
	@$(PYTEST) $(TB_DIR)/cocotb/cocotb_runner.py -v --tb=short --junitxml=$(BUILD_DIR)/cocotb-results.xml
	@echo "[TEST] Cocotb tests complete"

cocotb-smoke: $(BUILD_DIR)
	@echo "[TEST] Running cocotb smoke tests..."
	@$(PYTEST) $(TB_DIR)/cocotb/cocotb_runner.py -v -m smoke --tb=short --junitxml=$(BUILD_DIR)/cocotb-smoke-results.xml
	@echo "[TEST] Cocotb smoke tests complete"

#------------------------------------------------------------------------------
# Compliance Tests (RV64 default; RV32 kept as legacy baseline)
#------------------------------------------------------------------------------
compliance: sim
	@echo "[TEST] Running RISC-V compliance tests (RV64)..."
	@$(MAKE) -C $(TB_DIR)/compliance -f Makefile.rv64 run
	@echo "[TEST] Compliance tests complete"

compliance-rv32: sim
	@echo "[TEST] Running RISC-V compliance tests (RV32 legacy)..."
	@$(MAKE) -C $(TB_DIR)/compliance run
	@echo "[TEST] Compliance tests complete"

#------------------------------------------------------------------------------
# Full Regression
#------------------------------------------------------------------------------
cpp-suite: sim
	@$(SIM) --suite all

regress: lint unit cocotb compliance compliance-rv32 cpp-suite
	@echo "=========================================="
	@echo "[REGRESS] All regression tests PASSED"
	@echo "=========================================="

#------------------------------------------------------------------------------
# Synthesis
#------------------------------------------------------------------------------
synth: $(BUILD_DIR)
	@echo "[SYNTH] Running Yosys synthesis..."
	@$(MAKE) -C scripts/synth

asic-feas: $(BUILD_DIR)
	@echo "[ASIC] OpenLane feasibility (needs PDK image)..."
	@$(MAKE) -C asic

#------------------------------------------------------------------------------
# Waveform Viewer
#------------------------------------------------------------------------------
waves:
	@if [ -f $(WAVE_DIR)/dump.fst ]; then \
		gtkwave $(WAVE_DIR)/dump.fst &; \
	else \
		echo "[WAVES] No waveform file found. Run tests first."; \
	fi

#------------------------------------------------------------------------------
# Build Directory
#------------------------------------------------------------------------------
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(WAVE_DIR)

#------------------------------------------------------------------------------
# Clean
#------------------------------------------------------------------------------
clean:
	@echo "[CLEAN] Removing build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(WAVE_DIR)
	@rm -rf obj_dir
	@rm -rf __pycache__
	@rm -rf $(TB_DIR)/**/__pycache__
	@rm -rf $(TB_DIR)/**/sim_build
	@rm -rf .pytest_cache
	@find . -name "*.pyc" -delete
	@find . -name "*.fst" -delete
	@find . -name "*.vcd" -delete
	@echo "[CLEAN] Done"

#------------------------------------------------------------------------------
# Docs
#------------------------------------------------------------------------------
check-docs:
	@echo "[DOCS] Running guardrails..."
	@python3 tools/check_docs.py

docs:
	@echo "[DOCS] Building technical manual..."
	@./scripts/build-docs.sh

docs-clean:
	@echo "[DOCS] Removing built manual..."
	@rm -rf build/docs
	@echo "[DOCS] Done"

docs-open: docs
	@echo "[DOCS] Serving manual at http://localhost:8000/ ..."
	@python3 -m http.server 8000 --directory build/docs

#------------------------------------------------------------------------------
# Docker
#------------------------------------------------------------------------------
docker-build:
	@echo "[DOCKER] Building development container..."
	@docker build -f docker/Dockerfile.dev -t rv64xo3-dev .

docker-ci-build:
	@echo "[DOCKER] Building CI container..."
	@docker build -f docker/Dockerfile.ci -t rv64xo3-ci .

docker-shell:
	@echo "[DOCKER] Launching interactive shell..."
	@docker run -it --rm -v $(PWD):/workspace rv64xo3-dev
