# IronCore RV64IM Processor - Build System
# Canonical entrypoint for all project operations

.PHONY: all clean lint format unit cocotb compliance regress synth help
.PHONY: docker-build docker-shell waves

# Configuration
TOPLEVEL := ironcore_top
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
PYTEST := pytest

# RTL sources (order matters for dependencies)
RTL_SRCS := \
	$(RTL_DIR)/include/ironcore_pkg.sv \
	$(RTL_DIR)/ironcore_alu.sv \
	$(RTL_DIR)/ironcore_muldiv.sv \
	$(RTL_DIR)/ironcore_decoder.sv \
	$(RTL_DIR)/ironcore_if.sv \
	$(RTL_DIR)/ironcore_id.sv \
	$(RTL_DIR)/ironcore_ex.sv \
	$(RTL_DIR)/ironcore_mem.sv \
	$(RTL_DIR)/ironcore_bp.sv \
	$(RTL_DIR)/ironcore_hazard.sv \
	$(RTL_DIR)/ironcore_csr.sv \
	$(RTL_DIR)/ironcore_top.sv
RTL_INCS := $(RTL_DIR)/include

# Verilator flags
VERILATOR_FLAGS := \
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
	-I$(RTL_INCS)

# Verilator lint-only flags
VERILATOR_LINT_FLAGS := \
	--lint-only \
	-Wall \
	-Wno-UNUSEDSIGNAL \
	-Wno-IMPORTSTAR \
	--top-module ironcore_top \
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
	@echo "IronCore RV64IM Processor - Build Targets"
	@echo "=========================================="
	@echo ""
	@echo "Quality Gates:"
	@echo "  make lint       - Run Verible + Verilator linting"
	@echo "  make format     - Format RTL with Verible"
	@echo ""
	@echo "Testing:"
	@echo "  make unit       - Run unit tests"
	@echo "  make cocotb     - Run cocotb integration tests"
	@echo "  make compliance - Run RISC-V compliance tests"
	@echo "  make regress    - Full regression (lint + all tests)"
	@echo ""
	@echo "Synthesis:"
	@echo "  make synth      - Run synthesis (Yosys)"
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
	@if command -v $(VERIBLE_LINT) \u003e/dev/null 2\u003e\u00261; then \
		$(VERIBLE_LINT) $(VERIBLE_LINT_RULES) $(RTL_SRCS) || (echo "[LINT] Verible lint failed" \u0026\u0026 exit 1); \
	else \
		echo "[LINT] WARNING: Verible not found. Install from:"; \
		echo "  https://github.com/chipsalliance/verible/releases"; \
		echo "  Or run: make docker-shell"; \
		echo "[LINT] Skipping Verible lint..."; \
	fi

lint-verilator:
	@echo "[LINT] Running Verilator lint..."
	@if command -v $(VERILATOR) \u003e/dev/null 2\u003e\u00261; then \
		$(VERILATOR) $(VERILATOR_LINT_FLAGS) $(RTL_SRCS) || (echo "[LINT] Verilator lint failed" \u0026\u0026 exit 1); \
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
# Unit Tests
#------------------------------------------------------------------------------
unit: $(BUILD_DIR)
	@echo "[TEST] Running unit tests..."
	@$(PYTEST) $(TB_DIR)/unit -v --tb=short --junitxml=$(BUILD_DIR)/unit-results.xml

#------------------------------------------------------------------------------
# Cocotb Integration Tests
#------------------------------------------------------------------------------
cocotb: $(BUILD_DIR)
	@echo "[TEST] Running cocotb tests..."
	@$(MAKE) -C $(TB_DIR)/cocotb/alu
	@$(MAKE) -C $(TB_DIR)/cocotb/decoder
	@$(MAKE) -C $(TB_DIR)/cocotb/csr
	@echo "[TEST] Cocotb tests complete"

cocotb-smoke: $(BUILD_DIR)
	@echo "[TEST] Running cocotb smoke tests..."
	@$(MAKE) -C $(TB_DIR)/cocotb/alu
	@echo "[TEST] Cocotb smoke tests complete"

#------------------------------------------------------------------------------
# Compliance Tests
#------------------------------------------------------------------------------
compliance: $(BUILD_DIR)
	@echo "[TEST] Running RISC-V compliance tests..."
	@$(MAKE) -C $(TB_DIR)/compliance run
	@echo "[TEST] Compliance tests complete"

#------------------------------------------------------------------------------
# Full Regression
#------------------------------------------------------------------------------
regress: lint unit cocotb compliance
	@echo "=========================================="
	@echo "[REGRESS] All regression tests PASSED"
	@echo "=========================================="

#------------------------------------------------------------------------------
# Synthesis
#------------------------------------------------------------------------------
synth: $(BUILD_DIR)
	@echo "[SYNTH] Running Yosys synthesis..."
	@$(MAKE) -C scripts/synth

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
# Docker
#------------------------------------------------------------------------------
docker-build:
	@echo "[DOCKER] Building development container..."
	@docker build -t ironcore-dev .

docker-shell:
	@echo "[DOCKER] Launching interactive shell..."
	@docker run -it --rm -v $(PWD):/workspace ironcore-dev
