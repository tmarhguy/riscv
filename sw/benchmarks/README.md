# IronCore Benchmark Infrastructure

This directory contains benchmark programs for measuring IronCore performance.

## Benchmarks

### CoreMark
Industry-standard embedded benchmark from EEMBC.
- **Location**: `coremark/`
- **Metrics**: CoreMark score, CoreMark/MHz, IPC
- **Status**: Setup in progress

### Dhrystone
Classic integer performance benchmark.
- **Location**: `dhrystone/`
- **Metrics**: DMIPS, DMIPS/MHz
- **Status**: Setup in progress

## Running Benchmarks

```bash
# Build all benchmarks
make -C benchmarks

# Run CoreMark
make -C benchmarks coremark

# Run Dhrystone
make -C benchmarks dhrystone
```

## Performance Counter Integration

The benchmarks use the RISC-V performance counters:
- `cycle` - Total cycles elapsed
- `instret` - Instructions retired

These are accessed via CSR instructions and used to calculate IPC and frequency-normalized metrics.
