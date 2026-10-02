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
