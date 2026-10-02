# Phase 3: branch prediction

RTL simulation on Apple Silicon, Verilator 5.052; local date 2026-10-01,
UTC date 2026-10-02. Both slots query a shared 256-entry gshare table,
carry the fetch-time index for training, and use a tagged target cache
for indirect jumps plus a 16-entry resolved return-address stack.
Older control transfers win updates; simultaneous younger control
transfers can miss training, without changing architectural execution.
The RAS updates on resolved execution rather than speculative fetch.

Direction/target mismatches redirect; correctly predicted taken transfers
still kill younger slot work and check target alignment. A predicted
misaligned transfer initially bypassed the old redirect-based trap check;
checking resolved taken targets restored ma_fetch compliance. Buffered
prediction steering now drains outstanding fetch responses through IDLE.

`make regress` passed unit 58/58, cocotb runners 8/8, C++ 15/15,
RV64UI 54/54, RV64UM 13/13, RV64MI 15/15, RV32UI 37/37, RV32UM 8/8.
Verilator lint passed; Verible remains unavailable. Added predictor tests
cover saved gshare indexes, BTB tags, RAS overflow/underflow and nested
calls/returns. A subsequent top rerun passed all 10 processor tests and
the hello demo, including slot-B loop exit and wrong-path suppression.
The dual-issue tree remains 19 cycles (<32).

Also repaired literal escaped redirection/operators in the lint recipes,
which could previously hide lint failures. Logs: build/phase3-regress.log,
build/phase3-bp.log, build/phase3-recovery.log (ignored artifacts).

## CI portability follow-up

The first post-Phase-3 CI run exposed tool compatibility issues hidden by
local-only checks. Verilator rejects nonblocking reset-loop writes to the
predictor tables, so table initialization now uses initial values while the
history and RAS pointer retain reset behavior. Yosys 0.33 also rejects
unpacked array ports, struct member selection on a function result, return
statements, and an unbased literal in the register-file read function. The
predictor and rename interfaces are now packed, prediction outputs use a
packed function result, and helper functions use portable result
assignments.

Separating `ctrl.stall_if` from the other control bundle assignments removed
Verilator's `serialize_pair` combinational-loop warning. The Yosys
structural synthesis smoke runs with `-noabc`; this avoids spending minutes
mapping the combinational 64-bit multiplier while still checking RTL
parsing, hierarchy, process lowering, memory handling, and technology
mapping. RTL simulation regression remains the functional check.

Follow-up evidence: Verilator lint passed; Yosys 0.69 structural synthesis
passed; branch-predictor cocotb passed; `make regress` passed unit 58/58,
cocotb runners 8/8, C++ 15/15, RV64 82/82, and RV32 45/45. Verible was
unavailable locally and skipped.

## Verified GitHub CI repair

The earlier portability follow-up was verified locally, but did not fix the
Ubuntu jobs. On 2026-10-01 local time, the remaining failures were resolved:

* `serialize_pair` now reads an independent scalar decode-stall condition,
  avoiding the older Verilator's packed-control dependency cycle.
* Predictor and rename ports use flat vectors, with predictor tests updated
  to access packed slots explicitly.
* Failed synthesis prints the final 80 log lines. This exposed Yosys 0.33's
  rejection of package imports at the first ALU source, before those ports.
  CI now pins OSS CAD Suite 2026-10-01 (Yosys 0.69+173).
* Replaced an invalid setup-python revision with the verified v5 revision.
  Cocotb 2 requires VPI methods absent in Ubuntu Verilator 5.020, so the
  simulation job also uses the pinned suite. Lint still exercises 5.020.

Local `make regress` passed: unit 58, cocotb runners 8, C++ 15,
RV64UI 54, RV64UM 13, RV64MI 15, RV32UI 37, RV32UM 8; no failures.
Local synthesis passed. GitHub synthesis run 36957282399 passed with the
pinned suite; the old-Verilator lint job also passed. Verible remains
unavailable and is explicitly skipped. Logs: build/ci-fix-regress.log and
build/ci-fix-synth.log.
