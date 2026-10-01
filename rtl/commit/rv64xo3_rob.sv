// riscv64xO3 reorder buffer (scaffolding toward precise in-order commit).
// Allocate in order at dispatch, retire up to COMMIT_WIDTH at head.
import rv64xo3_pkg::*;

module rv64xo3_rob #(
    parameter int SZ = rv64xo3_pkg::ROB_SZ
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic [1:0] alloc_vld_i,
    output logic alloc_rdy_o,
    input  logic [1:0] cmpl_vld_i,
    output logic [1:0] retire_vld_o,
    output logic trap_flush_o
);
  assign alloc_rdy_o = !flush_i;
  assign retire_vld_o = cmpl_vld_i & {2{!flush_i}};
  assign trap_flush_o = 1'b0;
  // TODO: picks up allocation pointers, mispredict/trap rollback to head.
endmodule
