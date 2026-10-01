// riscv64xO3 reservation stations (scaffolding).
// Tomasulo wakeup/select lands here; not yet in the commit path.
import rv64xo3_pkg::*;

module rv64xo3_rs #(
    parameter int DEPTH = 8
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic dispatch_vld_i,
    output logic dispatch_rdy_o,
    input  logic cdb_vld_i,
    input  logic [$clog2(rv64xo3_pkg::PRF_SZ)-1:0] cdb_tag_i,
    output logic issue_vld_o
);
  assign dispatch_rdy_o = !flush_i;
  assign issue_vld_o = dispatch_vld_i && !flush_i;
  // TODO: tag RAM, ready bits, oldest-ready select, CDB broadcast.
endmodule
