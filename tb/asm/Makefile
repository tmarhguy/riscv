# IronCore Assembly Test Build
# Assembles verification tests

# Toolchain
CROSS_PREFIX ?= riscv-none-elf-
CC = $(CROSS_PREFIX)gcc
AS = $(CROSS_PREFIX)as
LD = $(CROSS_PREFIX)ld
OBJCOPY = $(CROSS_PREFIX)objcopy
OBJDUMP = $(CROSS_PREFIX)objdump

# Directories
BUILD_DIR = build

# Compiler flags
ARCH = rv32im_zicsr
ABI = ilp32
ASFLAGS = -march=$(ARCH) -mabi=$(ABI)
CFLAGS = -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -I.

# Linker flags
LDFLAGS = -T link_test.ld -nostdlib

# Test sources
TESTS = \
	test_alu \
	test_forwarding \
	test_stalls \
	test_branches \
	test_jumps \
	test_load_store \
	test_muldiv \
	test_traps

# Build outputs
TEST_ELFS = $(addprefix $(BUILD_DIR)/, $(addsuffix .elf, $(TESTS)))
TEST_BINS = $(addprefix $(BUILD_DIR)/, $(addsuffix .bin, $(TESTS)))
TEST_HEXS = $(addprefix $(BUILD_DIR)/, $(addsuffix .hex, $(TESTS)))

.PHONY: all clean disasm

all: $(TEST_ELFS) $(TEST_BINS) $(TEST_HEXS)
	@echo "Built $(words $(TESTS)) tests"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Preprocess and assemble
$(BUILD_DIR)/%.o: %.S test_macros.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link
$(BUILD_DIR)/%.elf: $(BUILD_DIR)/%.o link_test.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

# Create binary
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@

# Create hex (for Verilog $readmemh)
$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O verilog $< $@

# Disassembly for debugging
disasm: $(TEST_ELFS)
	@for elf in $(TEST_ELFS); do \
		echo "=== $$elf ==="; \
		$(OBJDUMP) -d $$elf > $${elf%.elf}.dis; \
	done

clean:
	rm -rf $(BUILD_DIR)
