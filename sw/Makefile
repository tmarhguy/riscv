# IronCore Software Build
# Compiles bare-metal C programs for RV32IM

# Toolchain
CROSS_PREFIX ?= riscv-none-elf-
CC = $(CROSS_PREFIX)gcc
AS = $(CROSS_PREFIX)as
LD = $(CROSS_PREFIX)ld
OBJCOPY = $(CROSS_PREFIX)objcopy
OBJDUMP = $(CROSS_PREFIX)objdump
SIZE = $(CROSS_PREFIX)size

# Directories
BUILD_DIR = build
SRC_DIR = .

# Compiler flags
ARCH = rv32im_zicsr
ABI = ilp32
CFLAGS = -march=$(ARCH) -mabi=$(ABI) -O2 -g
CFLAGS += -ffreestanding -nostdlib -nostartfiles
CFLAGS += -Wall -Wextra -Werror
CFLAGS += -fno-builtin -fno-common

# Linker flags
LDFLAGS = -T link.ld -nostdlib

# Source files
C_SRCS = hello.c
ASM_SRCS = crt0.S
OBJS = $(addprefix $(BUILD_DIR)/, $(C_SRCS:.c=.o) $(ASM_SRCS:.S=.o))

# Target
TARGET = $(BUILD_DIR)/hello

.PHONY: all clean disasm hex

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).vmem

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

$(TARGET).vmem: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@

disasm: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $(TARGET).dis

clean:
	rm -rf $(BUILD_DIR)
