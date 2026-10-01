<h1 align="center">Atlas</h1>
<p align="center"><strong>A 64-bit out-of-order superscalar RISC-V core (RV64IMAC), from RTL to silicon feasibility.</strong></p>
<p align="center">
  <a href="docs/index.adoc"><img alt="Status: active development" src="https://img.shields.io/badge/status-active%20development-2ea043"></a>
  <a href="docs/index.adoc"><img alt="Architecture: RV64IMAC OoO" src="https://img.shields.io/badge/architecture-RV64IMAC%20OoO-011F5B"></a>
  <a href="docs/isa/rv64xo3.csv"><img alt="ISA: RV64IMAC + Zicsr" src="https://img.shields.io/badge/ISA-RV64IMAC%2BZicsr-DC2626"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
</p>

**Explore:** [technical manual](docs/index.adoc) ·
[ISA contract](docs/isa/rv64xo3.csv) ·
[history](docs/log/)

## Architecture at a glance

2-wide fetch/decode/issue/commit. Tomasulo reservation stations, 96-entry
physical register file, 64-entry ROB, 16-entry LSQ, bimodal predictor.
AXI4-Lite native. M-mode precise traps. See the
[technical manual](docs/index.adoc).

```mermaid
graph LR
  IF[Fetch 2-wide] --> ID[Rename/Dispatch]
  ID --> IS[RS + Execute]
  IS --> MEM[LSQ + AXI]
  MEM --> CM[ROB Commit]
```

## What runs now

| Layer | Current, repository-backed statement |
|---|---|
| ISA | RV64IM implemented; A/C in bring-up (`docs/isa/rv64xo3.csv`) |
| Core | 5-stage scalar pipeline renamed to `rv64xo3_*`; OoO scaffolding landing |
| Bus | AXI4-Lite IMEM/DMEM masters |
| Verification | Verilator + cocotb + `riscv-tests` RV64UI/UM |
| ASIC | Yosys synth smoke + OpenLane2 feasibility (`asic/`) |

Use the [technical manual](docs/index.adoc) for evidence boundaries. History lives
in [`docs/log/`](docs/log/).

## See it, run it, inspect it

### Local RTL simulation

```bash
make docker-build
make docker-shell
# inside:
make regress
```

### Focused checks

```bash
python3 tools/check_docs.py
make lint
make unit cocotb-smoke
```

### Technical manual

```bash
make docs       # build to build/docs/
make docs-open  # serve locally
```

## Repository map

| Path | Purpose |
|---|---|
| [`rtl/`](rtl/) | SystemVerilog source (synthesizable) |
| [`tb/`](tb/) | Unit, cocotb, compliance, formal |
| [`docs/`](docs/index.adoc) | Technical manual source (AsciiDoc) + ISA contract + history |
| [`asic/`](asic/) | Synth + OpenLane feasibility |
| [`sw/`](sw/) | CRT, linker scripts, bare-metal examples |
| [`tools/`](tools/) | Docs guardrails, ISA generators |
| [`docker/`](docker/) | Dev + CI images |

## Documentation

Detailed architecture, implementation, verification, and technical documentation is available in the project documentation.

Start with [`docs/index.adoc`](docs/index.adoc) (builds to `build/docs/` via `make docs`). Authority order: `rtl/` SystemVerilog, then the manual's current facts, then machine-readable contracts (`docs/isa/rv64xo3.csv`), then other prose, then `docs/log/` history.

## License and author

MIT License. See [LICENSE](LICENSE).

**Author:** Tyrone Marhguy — Computer Engineering ’28, University of Pennsylvania.
[Contributing](CONTRIBUTING.md) · [security](SECURITY.md) · [citation](CITATION.cff)
