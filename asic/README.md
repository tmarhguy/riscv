# ASIC Directory

This directory contains configuration and reports for ASIC feasibility studies using OpenLane and the SkyWater 130nm PDK.

## Purpose
To demonstrate that the IronCore RTL is physically realizable in silicon, providing estimates for area, timing, and power.

## Workflow
We use **OpenLane**, an automated RTL-to-GDSII flow.

## Key Files
*   `config.tcl` / `config.json`: OpenLane configuration (constraints, clock period, floorplanning).
*   `runs/`: Output directory for synthesis and PnR runs (not committed).

## How to Run
(Requires OpenLane installation)

```bash
make asic-feasibility
# OR
flow.tcl -design . -tag run1
```

## Status
*   **Feasibility**: Synthesis reports confirm the design fits within target area constraints.
*   **Timing**: Closes timing at target frequency (see latest reports in `logs/`).
