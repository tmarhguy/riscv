# Cocotb Makefile for IronCore Decoder

SIM ?= verilator
TOPLEVEL_LANG ?= verilog

# Paths
RTL_DIR = $(PWD)/../../../rtl

# Source files
VERILOG_SOURCES += $(RTL_DIR)/include/ironcore_pkg.sv
VERILOG_SOURCES += $(RTL_DIR)/ironcore_decoder.sv

# Top-level module
TOPLEVEL = ironcore_decoder

# Python test module
MODULE = test_decoder

# Verilator-specific
EXTRA_ARGS += --trace-fst --trace-structs
EXTRA_ARGS += -Wno-fatal
EXTRA_ARGS += --timing
EXTRA_ARGS += --coverage

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim
