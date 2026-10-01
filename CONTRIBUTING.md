# Contributing to riscv64xO3

Small, evidence-backed changes are easiest to review.

## Before opening a change

- Start from the technical manual ([`docs/index.adoc`](docs/index.adoc),
  chapters 1 and 9 first).
- Keep simulation, FPGA, and silicon claims distinct.
- Do not rewrite `docs/log/` history as current prose.
- Never commit `*.o/*.elf/*.hex/*.vcd/*.fst/results.xml/coverage.dat`.
- Use commits as `type(scope): subject`:
   `feat(rtl)`, `fix(tb)`, `docs`, `test`, `chore`, `asic`, `signoff`.

## Focused checks

```bash
python3 tools/check_docs.py
make lint
make unit cocotb-smoke
```

Simulation passing does not prove hardware. Describe exactly what was run.
