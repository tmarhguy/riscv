# Changelog

## [1.0.0] - 2026-02-16

### Added
- **Core**: Initial release of IronCore 5-stage pipeline (RV64IM).
- **Hazard Unit**: Full forwarding (EX->ID, MEM->ID) and load-use stall detection.
- **Branch Prediction**: Bimodal predictor with configurable table size (default 2-bit counters).
- **Interface**: Wishbone B4 (Pipeline) Master interface for Instruction and Data.
- **Verification**: 
    - Full RV32IM compliance test suite passing (100%).
    - Pytest unit tests for ALU, Decoder, CSRs.
    - Cocotb integration tests for pipeline hazards.
- **Build System**: Makefile-driven workflow with Docker support.

### Known Issues
- `mstatus` only supports M-mode (no User/Supervisor support yet).
- Coverage is currently ~61%, with plans to reach 95% in v1.1.
