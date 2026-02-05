# IronCore OpenLane Configuration
# Target: SKY130

set ::env(PDK) "sky130A"
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"

# Design
set ::env(DESIGN_NAME) "ironcore_top"

# Source Files
if {![info exists ::env(VERILOG_ROOT)]} {
    set ::env(VERILOG_ROOT) "$::env(DESIGN_DIR)/../rtl"
}

set ::env(VERILOG_FILES) [list \
    $::env(VERILOG_ROOT)/include/ironcore_pkg.sv \
    $::env(VERILOG_ROOT)/ironcore_alu.sv \
    $::env(VERILOG_ROOT)/ironcore_muldiv.sv \
    $::env(VERILOG_ROOT)/ironcore_decoder.sv \
    $::env(VERILOG_ROOT)/ironcore_if.sv \
    $::env(VERILOG_ROOT)/ironcore_id.sv \
    $::env(VERILOG_ROOT)/ironcore_ex.sv \
    $::env(VERILOG_ROOT)/ironcore_mem.sv \
    $::env(VERILOG_ROOT)/ironcore_bp.sv \
    $::env(VERILOG_ROOT)/ironcore_hazard.sv \
    $::env(VERILOG_ROOT)/ironcore_csr.sv \
    $::env(VERILOG_ROOT)/ironcore_top.sv \
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
