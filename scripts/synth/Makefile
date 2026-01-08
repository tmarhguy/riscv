# IronCore Synthesis Scripts
# Yosys-based synthesis for area/timing estimates

DESIGN = ironcore_top
RTL_DIR = ../../rtl
BUILD_DIR = build

# RTL sources
SRCS = \
	$(RTL_DIR)/include/ironcore_pkg.sv \
	$(RTL_DIR)/ironcore_alu.sv \
	$(RTL_DIR)/ironcore_muldiv.sv \
	$(RTL_DIR)/ironcore_decoder.sv \
	$(RTL_DIR)/ironcore_if.sv \
	$(RTL_DIR)/ironcore_id.sv \
	$(RTL_DIR)/ironcore_ex.sv \
	$(RTL_DIR)/ironcore_mem.sv \
	$(RTL_DIR)/ironcore_bp.sv \
	$(RTL_DIR)/ironcore_hazard.sv \
	$(RTL_DIR)/ironcore_csr.sv \
	$(RTL_DIR)/ironcore_top.sv

.PHONY: all clean yosys-synth report

all: yosys-synth report

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Yosys synthesis for generic FPGA
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
		synth; \
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
