SIM ?= verilator
TOPLEVEL_LANG ?= verilog

# Normalize PWD to be the directory of this Makefile
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CUR_DIR := $(dir $(MKFILE_PATH))
RTL_DIR := $(abspath $(CUR_DIR)/../../../rtl)

VERILOG_SOURCES += $(RTL_DIR)/include/ironcore_pkg.sv
VERILOG_SOURCES += $(RTL_DIR)/ironcore_muldiv.sv

TOPLEVEL = ironcore_muldiv
MODULE = test_muldiv

EXTRA_ARGS += -I$(RTL_DIR)/include --trace-fst --trace-structs

include $(shell cocotb-config --makefiles)/Makefile.sim
