# Cocotb Makefile for IronCore

# Simulator
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

# Source files
VERILOG_SOURCES += $(PWD)/../../rtl/include/ironcore_pkg.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_alu.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_muldiv.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_decoder.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_if.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_id.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_ex.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_mem.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_bp.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_hazard.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_csr.sv
VERILOG_SOURCES += $(PWD)/../../rtl/ironcore_top.sv

# Top-level module
TOPLEVEL = ironcore_top

# Python test module
MODULE = test_ironcore

# Verilator-specific
EXTRA_ARGS += --trace-fst --trace-structs
EXTRA_ARGS += -Wno-fatal
EXTRA_ARGS += --timing

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim
