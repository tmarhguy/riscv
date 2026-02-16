# IronCore Performance Benchmarks

## Overview
Performance metrics measured on the compiled RTL simulation (Verilator).

## Dhrystone 2.1
**Config**:
- Run Count: 100
- Compiler: GCC 15.1.0, `-O2`
- Architecture: RV64IM_Zicsr

**Results**:
- **Cycles/Run**: 1174
- **DMIPS/MHz**: 0.49  (Calculated as `(10^6 / 1174) / 1757`)
- **IPC**: TBD (Counter bug in current run)

**Analysis**:
Current performance is limited by the lack of caches. Instruction fetch and data access over the Wishbone bus incur multi-cycle latencies (approx 2-3 cycles per access). A dedicated instruction cache or tightly coupled memory (TCM) would significantly improve IPC towards the theoretical max of 1.0.

## CoreMark
*Pending Porting*

## FPGA Synthesis (Artix-7)
*Pending*
