# riscv64xO3 OpenLane2/LibreLane Configuration
# Target: SKY130 (sky130A / sky130_fd_sc_hd)
# Canonical JSON: asic/config.json. This TCL stays for OpenLane1 compat.

set ::env(PDK) "sky130A"
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"

# Design
set ::env(DESIGN_NAME) "rv64xo3_top"

# Source Files
if {![info exists ::env(VERILOG_ROOT)]} {
    set ::env(VERILOG_ROOT) "$::env(DESIGN_DIR)/../rtl"
}

set ::env(VERILOG_FILES) [list \
    $::env(VERILOG_ROOT)/include/rv64xo3_pkg.sv \
    $::env(VERILOG_ROOT)/rv64xo3_alu.sv \
    $::env(VERILOG_ROOT)/rv64xo3_muldiv.sv \
    $::env(VERILOG_ROOT)/rv64xo3_decoder.sv \
    $::env(VERILOG_ROOT)/rv64xo3_if.sv \
    $::env(VERILOG_ROOT)/rv64xo3_id.sv \
    $::env(VERILOG_ROOT)/rv64xo3_ex.sv \
    $::env(VERILOG_ROOT)/rv64xo3_mem.sv \
    $::env(VERILOG_ROOT)/rv64xo3_bp.sv \
    $::env(VERILOG_ROOT)/rv64xo3_hazard.sv \
    $::env(VERILOG_ROOT)/rv64xo3_hazard_sva.sv \
    $::env(VERILOG_ROOT)/rv64xo3_csr.sv \
    $::env(VERILOG_ROOT)/issue/rv64xo3_rename.sv \
    $::env(VERILOG_ROOT)/issue/rv64xo3_rs.sv \
    $::env(VERILOG_ROOT)/memory/rv64xo3_lsq.sv \
    $::env(VERILOG_ROOT)/commit/rv64xo3_rob.sv \
    $::env(VERILOG_ROOT)/rv64xo3_top.sv \
]

# Clock
set ::env(CLOCK_PORT) "clk_i"
set ::env(CLOCK_PERIOD) 10.0
# set ::env(CLOCK_NET) $::env(CLOCK_PORT)

# Timing
set ::env(RUN_CTS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 1

# Floorplanning
set ::env(FP_SIZING) "relative"
set ::env(FP_CORE_UTIL) 50
set ::env(FP_ASPECT_RATIO) 1
set ::env(FP_PDN_VOFFSET) 10
set ::env(FP_PDN_VPITCH) 30
set ::env(FP_PDN_HOFFSET) 10
set ::env(FP_PDN_HPITCH) 30

# Placement
set ::env(PL_TARGET_DENSITY) 0.55
# set ::env(PL_TIME_DRIVEN) 1

# Routing
# set ::env(GLB_RT_ADJUSTMENT) 0.15

# Linter
# set ::env(RUN_LINTER) 1
# set ::env(QUIT_ON_LINTER_ERRORS) 0

# Flow
set ::env(RUN_KLAYOUT) 0
set ::env(RUN_CVC) 0
set ::env(RUN_MAGIC) 1
