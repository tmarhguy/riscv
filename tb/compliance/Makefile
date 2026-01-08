# RISC-V Compliance Test Runner
# Runs riscv-tests suite against IronCore

# Toolchain
RISCV_PREFIX ?= riscv64-unknown-elf-
OBJCOPY = $(RISCV_PREFIX)objcopy

# Test Locations (try brew first, then local)
BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /opt/homebrew)
RISCV_TESTS_BREW := $(BREW_PREFIX)/share/riscv-tests
RISCV_TESTS_HOME ?= $(HOME)/riscv-tests

ifneq ($(wildcard ../riscv-tests/isa/rv32ui-p-add),)
    RISCV_TESTS_DIR = ../riscv-tests/isa
else ifneq ($(wildcard $(RISCV_TESTS_BREW)/isa/rv32ui-p-add),)
    RISCV_TESTS_DIR = $(RISCV_TESTS_BREW)/isa
else
    RISCV_TESTS_DIR = $(RISCV_TESTS_HOME)/isa
endif

BUILD_DIR = build
SIM = ../../build/obj_dir/ironcore_sim

# Test suites
RV32UI_TESTS = \
	add addi and andi auipc \
	beq bge bgeu blt bltu bne \
	jal jalr \
	lb lbu lh lhu lw \
	lui \
	or ori \
	sb sh sw \
	sll slli slt slti sltiu sltu \
	sra srai srl srli \
	sub \
	xor xori

RV32UM_TESTS = \
	mul mulh mulhsu mulhu \
	div divu rem remu

.PHONY: all run clean rv32ui rv32um

all: run

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Run all tests
run: rv32ui rv32um
	@mkdir -p logs
	@echo "=== Compliance Test Summary ==="
	@echo "RV32UI: $$(grep PASS $(BUILD_DIR)/rv32ui-*.log | wc -l) passed"
	@echo "RV32UM: $$(grep PASS $(BUILD_DIR)/rv32um-*.log | wc -l) passed"

# RV32UI tests
rv32ui: $(BUILD_DIR)
	@echo "Running RV32UI tests from $(RISCV_TESTS_DIR)..."
	@for test in $(RV32UI_TESTS); do \
		TEST_SRC=$(RISCV_TESTS_DIR)/rv32ui-p-$$test; \
		if [ -f $$TEST_SRC ]; then \
			echo -n "  $$test: "; \
			$(OBJCOPY) -O binary $$TEST_SRC $(BUILD_DIR)/rv32ui-p-$$test.bin; \
			if $(SIM) $(BUILD_DIR)/rv32ui-p-$$test.bin --timeout 2000000 > $(BUILD_DIR)/rv32ui-p-$$test.log 2>&1; then \
				mv logs/coverage.dat logs/coverage_rv32ui-p-$$test.dat 2>/dev/null || true; \
				echo "PASS"; \
			else \
				echo "FAIL"; \
			fi; \
		else \
			echo "SKIP (not found: $$TEST_SRC)"; \
		fi; \
	done

# RV32UM tests
rv32um: $(BUILD_DIR)
	@echo "Running RV32UM tests from $(RISCV_TESTS_DIR)..."
	@for test in $(RV32UM_TESTS); do \
		TEST_SRC=$(RISCV_TESTS_DIR)/rv32um-p-$$test; \
		if [ -f $$TEST_SRC ]; then \
			echo -n "  $$test: "; \
			$(OBJCOPY) -O binary $$TEST_SRC $(BUILD_DIR)/rv32um-p-$$test.bin; \
			if $(SIM) $(BUILD_DIR)/rv32um-p-$$test.bin --timeout 2000000 > $(BUILD_DIR)/rv32um-p-$$test.log 2>&1; then \
				mv logs/coverage.dat logs/coverage_rv32um-p-$$test.dat 2>/dev/null || true; \
				echo "PASS"; \
			else \
				echo "FAIL"; \
			fi; \
		else \
			echo "SKIP (not found: $$TEST_SRC)"; \
		fi; \
	done

clean:
	rm -rf $(BUILD_DIR)
