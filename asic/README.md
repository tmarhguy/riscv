# ASIC feasibility (sky130)

OpenLane2/LibreLane RTL-to-GDSII smoke for `rv64xo3_top`. This proves the RTL
is physically plausible and yields area/timing estimates. It is not a tapeout.

## Files

- `config.json`: canonical flow config (sources, clock, density).
- `config.tcl`: OpenLane1-compatible shim.
- `constraints.sdc`: 100 MHz nominal (`clk_i`, 10 ns).
- `runs/`, `logs/`, `reports/`: outputs, never committed.

## Run

```bash
make synth       # Yosys smoke (CI)
make asic-feas   # OpenLane feasibility (needs PDK)
```

## Status

See `docs/index.adoc` ch. 9 (Known Limitations). Yosys smoke must pass before any PnR run. Timing target
is 100 MHz nominal; push to 200 MHz once OoO commit lands.
