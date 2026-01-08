# Makefile for AXI4-Lite Bridge Tests

TOPLEVEL_LANG = verilog
SIM = verilator

# RTL sources
RTL_DIR = ../../../rtl
VERILOG_SOURCES = \
	$(RTL_DIR)/include/ironcore_pkg.sv \
	$(RTL_DIR)/ironcore_axi4lite_imem.sv \
	$(RTL_DIR)/ironcore_axi4lite_dmem.sv

# Test configuration
MODULE = test_axi_bridge
TOPLEVEL = ironcore_axi4lite_imem

# Verilator flags
EXTRA_ARGS += --trace-fst --trace-structs
COMPILE_ARGS += -I$(RTL_DIR)/include
COMPILE_ARGS += -Wno-UNUSEDSIGNAL

# Include cocotb makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim

# Test data memory bridge
test-dmem:
	$(MAKE) clean
	TOPLEVEL=ironcore_axi4lite_dmem $(MAKE)

.PHONY: test-dmem
