// riscv64xO3 hazard SVA checker (formal mirror of rv64xo3_hazard, 2-wide).
// Bound inside rv64xo3_top under `ifndef SYNTHESIS. Verilator-lint clean.
import rv64xo3_pkg::*;

module rv64xo3_hazard_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_a_rs1_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_a_rs2_addr,
    input logic id_a_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_b_rs1_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_b_rs2_addr,
    input logic id_b_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] ex_a_rd_addr,
    input logic ex_a_mem_read,
    input logic ex_a_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] ex_b_rd_addr,
    input logic ex_b_mem_read,
    input logic ex_b_valid,
    input logic load_use_hazard,
    input rv64xo3_pkg::fwd_sel_e fwd_a_sel_a,
    input rv64xo3_pkg::fwd_sel_e fwd_b_sel_a,
    input rv64xo3_pkg::fwd_sel_e fwd_a_sel_b,
    input rv64xo3_pkg::fwd_sel_e fwd_b_sel_b,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] mem_a_rd_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] mem_b_rd_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] wb_a_rd_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] wb_b_rd_addr
);
`ifndef SYNTHESIS
  // Load-use hazard must fire exactly when either EX slot holds a load to
  // x!=0 matching either ID slot source.
  always_comb begin
    logic expect_hazard;
    logic ex_a_hit;
    logic ex_b_hit;
    ex_a_hit = ex_a_valid && ex_a_mem_read && (ex_a_rd_addr != 5'd0) &&
               ((id_a_valid && ((ex_a_rd_addr == id_a_rs1_addr) ||
                                (ex_a_rd_addr == id_a_rs2_addr))) ||
                (id_b_valid && ((ex_a_rd_addr == id_b_rs1_addr) ||
                                (ex_a_rd_addr == id_b_rs2_addr))));
    ex_b_hit = ex_b_valid && ex_b_mem_read && (ex_b_rd_addr != 5'd0) &&
               ((id_a_valid && ((ex_b_rd_addr == id_a_rs1_addr) ||
                                (ex_b_rd_addr == id_a_rs2_addr))) ||
                (id_b_valid && ((ex_b_rd_addr == id_b_rs1_addr) ||
                                (ex_b_rd_addr == id_b_rs2_addr))));
    expect_hazard = ex_a_hit || ex_b_hit;
    if (rst_ni) begin
      assert (load_use_hazard == expect_hazard)
      else $error("hazard_sva: load_use mismatch");
    end
  end

  // Forwarding must never claim x0 as a source match.
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_a_sel_a == FWD_EX_A) |-> (mem_a_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_a_a from x0");
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_a_sel_b == FWD_EX_B) |-> (mem_b_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_a_b from x0");
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_b_sel_a == FWD_EX_A) |-> (mem_a_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_b_a from x0");
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_b_sel_b == FWD_EX_B) |-> (mem_b_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_b_b from x0");
`endif
endmodule
