# riscv64xO3 Synthesis Scripts
# Yosys-based synthesis for area/timing estimates

DESIGN = rv64xo3_top
RTL_DIR = ../../rtl
BUILD_DIR = build

# RTL sources
SRCS = \
	$(RTL_DIR)/include/rv64xo3_pkg.sv \
	$(RTL_DIR)/rv64xo3_alu.sv \
	$(RTL_DIR)/rv64xo3_muldiv.sv \
	$(RTL_DIR)/rv64xo3_decoder.sv \
	$(RTL_DIR)/rv64xo3_if.sv \
	$(RTL_DIR)/rv64xo3_id.sv \
	$(RTL_DIR)/rv64xo3_ex.sv \
	$(RTL_DIR)/rv64xo3_mem.sv \
	$(RTL_DIR)/rv64xo3_bp.sv \
	$(RTL_DIR)/rv64xo3_hazard.sv \
	$(RTL_DIR)/rv64xo3_hazard_sva.sv \
	$(RTL_DIR)/rv64xo3_csr.sv \
	$(RTL_DIR)/issue/rv64xo3_rename.sv \
	$(RTL_DIR)/issue/rv64xo3_rs.sv \
	$(RTL_DIR)/memory/rv64xo3_lsq.sv \
	$(RTL_DIR)/commit/rv64xo3_rob.sv \
	$(RTL_DIR)/rv64xo3_top.sv

.PHONY: all clean yosys-synth report

all: yosys-synth report

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Yosys structural synthesis smoke (technology-independent; skips ABC mapping
# so the single-cycle wide multiplier does not dominate CI runtime).
yosys-synth: $(BUILD_DIR)
	yosys -p "\
		read_verilog -sv $(SRCS); \
		hierarchy -top $(DESIGN); \
		proc; \
		opt; \
		fsm; \
		opt; \
		memory; \
		opt; \
		techmap; \
		opt; \
		synth -noabc; \
		write_json $(BUILD_DIR)/$(DESIGN).json; \
		stat" \
		> $(BUILD_DIR)/yosys.log 2>&1

# Generate reports
report: $(BUILD_DIR)/$(DESIGN).json
	@echo "=== Synthesis Report ===" > $(BUILD_DIR)/report.txt
	@grep -A 50 "Printing statistics" $(BUILD_DIR)/yosys.log >> $(BUILD_DIR)/report.txt
	@echo ""
	@echo "Synthesis report generated: $(BUILD_DIR)/report.txt"
	@cat $(BUILD_DIR)/report.txt

clean:
	rm -rf $(BUILD_DIR)
