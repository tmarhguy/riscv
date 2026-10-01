// riscv64xO3 load/store queue (scaffolding).
// Store-to-load forwarding + in-order store drain at commit.
import rv64xo3_pkg::*;

module rv64xo3_lsq #(
    parameter int SZ = rv64xo3_pkg::LSQ_SZ
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic load_vld_i,
    input  logic store_vld_i,
    output logic load_rdy_o,
    output logic store_rdy_o,
    output logic fwd_vld_o
);
  assign load_rdy_o = !flush_i;
  assign store_rdy_o = !flush_i;
  assign fwd_vld_o = 1'b0;
  // TODO: address CAM, store-set predictor, AXI4-Lite issue, misalign traps.
endmodule
