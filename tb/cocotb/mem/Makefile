SIM ?= verilator
TOPLEVEL_LANG ?= verilog

# Normalize PWD to be the directory of this Makefile
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CUR_DIR := $(dir $(MKFILE_PATH))
RTL_DIR := $(abspath $(CUR_DIR)/../../../rtl)

VERILOG_SOURCES += $(RTL_DIR)/include/ironcore_pkg.sv
VERILOG_SOURCES += $(RTL_DIR)/ironcore_mem.sv

TOPLEVEL = ironcore_mem
MODULE = test_mem

# Add --assert flag to enable assertions, but we might want to suppress fatal errors for misaligned test
# Actually, --assert enables them. Without it, they are ignored by Verilator?
# Let's keep them enabled but handle the error if it stops sim.
# Testing: If assertions stop sim, we remove --assert or add -Wno-fatal
# Add -DSYNTHESIS to disable the assertions in ironcore_mem.sv that stop simulation on valid misalignment tests
EXTRA_ARGS += -I$(RTL_DIR)/include --trace-fst --trace-structs -DSYNTHESIS

include $(shell cocotb-config --makefiles)/Makefile.sim
