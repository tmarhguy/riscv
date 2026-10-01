# Phase 1: non-blocking execute

Date: 2026-10-01. Local run (Apple Silicon, Verilator 5.052).

## Result

* MUL/MULH/MULHSU/MULHU/MULW are single-cycle combinational (1/cycle).
* DIV iterates in the background (65 cycles); at most one outstanding,
  tracked by destination in a scoreboard. Independent instructions flow;
  consumers and WAW writers stall; completion injects via a 1-cycle
  writeback stall. No whole-pipeline muldiv stall remains.

## Evidence

* `test_div_overlap`: 40 independent addi retire during one DIV, dependent
  consumer reads the right value — 97 cycles (fully-stalling design: ~160).
* `test_mul_throughput`: 8 back-to-back MULs in 27 cycles (~48 at 4/cycle).
* Regression green: RV64UI 54/54, RV64UM 13/13, RV64MI 15/15,
  RV32UI 37/37, RV32UM 8/8, unit 58/58, cocotb 7/7, C++ suites 15/15,
  legacy asm 8/8, lint clean.

## Bugs found on the way in

* Scoreboard freezing a VALID instruction in EX while MEM drained let its
  latched operands go stale as forwards drained (fixed: flush EX like a
  load-use so it advances once and drains; MEM takes a bubble instead of
  re-capturing frozen EX).
* Scoreboard rs2 is checked raw, so I-type ops with aliasing immediates
  can stall spuriously (safe; Tomasulo makes it moot).
* Same-rd WAW across an outstanding DIV needs a 65+ cycle bus stall plus
  rd collision to mis-forward; bus SRAM acks immediately here.
