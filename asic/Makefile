# IronCore ASIC Flow
# Uses OpenLane via Docker

OPENLANE_IMAGE ?= efabless/openlane:latest
PROJECT_ROOT ?= $(shell pwd)/..
CONFIG_DIR ?= $(shell pwd)
DESIGN_NAME ?= ironcore_top

.PHONY: all asic clean

all: asic

asic:
	@echo "Running OpenLane flow..."
	docker run --rm -v $(PROJECT_ROOT):/project \
		-v $(CONFIG_DIR):/config \
		-w /project \
		-e PDK_ROOT=/pdk \
		-e VERILOG_ROOT=/project/rtl \
		$(OPENLANE_IMAGE) \
		./flow.tcl -design /config -tag run1

clean:
	rm -rf runs
