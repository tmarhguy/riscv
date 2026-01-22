# Makefile for Dhrystone Benchmark

# Toolchain
RISCV_PREFIX ?= riscv64-unknown-elf-
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

# Flags
CFLAGS = -march=rv64im_zicsr -mabi=lp64 -mcmodel=medany -O2 -g
CFLAGS += -ffreestanding -nostdlib -nostartfiles
CFLAGS += -I../../
LDFLAGS = -T../../link64.ld -nostdlib

# Sources
SRCS = dhrystone.c uart.c ../../crt0_64.S
OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# Output
TARGET = dhrystone
ELF = $(TARGET).elf
BIN = $(TARGET).bin
HEX = $(TARGET).hex
DUMP = $(TARGET).dump

.PHONY: all clean

all: $(ELF) $(BIN) $(HEX) $(DUMP)

$(ELF): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(ELF)
	$(OBJCOPY) -O verilog $< $@

$(DUMP): $(ELF)
	$(OBJDUMP) -D $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(ELF) $(BIN) $(HEX) $(DUMP)
