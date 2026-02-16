# IronCore Synthesis Results (RV64IM)

*Evidence-based synthesis and physical implementation metrics*

## Synthesis Status

| Aspect | Status | Notes |
|--------|--------|-------|
| **RTL Synthesizability** | Verified | All modules pass Yosys synthesis |
| **FPGA Target** | Artix-7 | Xilinx 7-series FPGA family |
| **ASIC Feasibility** | Sky130 PDK | OpenLane flow configured |

## FPGA Synthesis (Yosys)

### Synthesis Configuration
- **Tool**: Yosys (Open Source Synthesis Suite)
- **Target**: Generic FPGA synthesis
- **RTL Modules**: 11 SystemVerilog modules
- **Top Module**: `ironcore_top`

### Synthesis Verification
The IronCore RTL successfully synthesizes with Yosys, confirming:
- No combinational loops
- No inferred latches (all registers explicit)
- Clean synthesis with no critical warnings
- All modules instantiate correctly

### Resource Utilization Estimate
*Note: Exact resource counts require vendor-specific synthesis (Vivado for Xilinx)*

Based on RTL complexity:
- **Estimated LUTs**: ~5,000-8,000 (for RV32IM with 5-stage pipeline)
- **Estimated FFs**: ~2,000-3,000 (pipeline registers + architectural state)
- **Block RAM**: Minimal (external memory interface)
- **DSP Blocks**: 0-2 (depending on multiplier implementation)

### Timing Estimates
- **Target Clock**: 50-100 MHz (conservative for Artix-7)
- **Critical Path**: Likely in ALU or hazard detection logic
- **Pipeline Depth**: 5 stages aids timing closure

## ASIC Feasibility (OpenLane + Sky130)

### Configuration
- **PDK**: SkyWater Sky130 (130nm open-source PDK)
- **Flow**: OpenLane automated RTL-to-GDSII
- **Config File**: [`asic/config.tcl`](file:///Users/tmarhguy/riscv/riscv/asic/config.tcl)

### Status
The ASIC flow configuration is complete and ready for execution. The design is structured to be physically realizable:

- Synthesizable RTL (no behavioral constructs)
- Single clock domain (simplifies physical design)
- Explicit reset strategy
- Standard cell compatible

### Expected Metrics
*Actual metrics require full OpenLane run*

Based on similar RV32I cores in Sky130:
- **Estimated Area**: 0.1-0.3 mm² (core only, no caches)
- **Estimated Frequency**: 50-150 MHz (post-layout)
- **Power**: TBD (requires full PnR)

## Synthesis Commands

### Run Yosys Synthesis
```bash
make synth
# OR
cd scripts/synth && make
```

### Run ASIC Flow (requires OpenLane)
```bash
cd asic
flow.tcl -design . -tag run1
```

## Verification of Synthesizability

The following checks confirm RTL synthesizability:

1. **Verilator Lint**: Passes with `--lint-only` flag
   ```bash
   make lint-verilator
   ```

2. **Verible Lint**: Passes SystemVerilog style checks
   ```bash
   make lint-verible
   ```

3. **Yosys Synthesis**: Completes without errors
   ```bash
   make synth
   ```

## Implementation Notes

### Design Choices for Synthesis
- **Synchronous Reset**: All registers use synchronous reset for better timing
- **Explicit State Machines**: All FSMs use explicit state encoding
- **Parameterized Design**: `XLEN=64`, `RESET_PC` configurable
- **No Vendor Primitives**: Pure SystemVerilog for portability

### Known Synthesis Considerations
- **Multiplier/Divider**: Iterative implementation trades area for latency
- **No Caches**: Reduces complexity and area
- **Simple Branch Predictor**: Minimal logic overhead

---
*For detailed synthesis logs and reports, see `scripts/synth/` and `asic/runs/`*
