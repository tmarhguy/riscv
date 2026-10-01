// riscv64xO3 hazard SVA checker (formal mirror of rv64xo3_hazard).
// Bound inside rv64xo3_top under `ifndef SYNTHESIS. Verilator-lint clean.
import rv64xo3_pkg::*;

module rv64xo3_hazard_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_rs1_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] id_rs2_addr,
    input logic id_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] ex_rs1_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] ex_rs2_addr,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] ex_rd_addr,
    input logic ex_mem_read,
    input logic ex_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] mem_rd_addr,
    input logic mem_reg_write,
    input logic mem_valid,
    input logic [rv64xo3_pkg::REG_ADDR_W-1:0] wb_rd_addr,
    input logic wb_reg_write,
    input logic wb_valid,
    input logic load_use_hazard,
    input rv64xo3_pkg::fwd_sel_e fwd_a_sel,
    input rv64xo3_pkg::fwd_sel_e fwd_b_sel
);
`ifndef SYNTHESIS
  // Load-use hazard must fire exactly when EX holds a load to x!=0
  // matching an ID source.
  always_comb begin
    logic expect_hazard;
    expect_hazard = id_valid && ex_valid && ex_mem_read &&
                    (ex_rd_addr != 5'd0) &&
                    ((ex_rd_addr == id_rs1_addr) || (ex_rd_addr == id_rs2_addr));
    if (rst_ni) begin
      assert (load_use_hazard == expect_hazard)
      else $error("hazard_sva: load_use mismatch");
    end
  end

  // Forwarding must never claim x0 as a source match.
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_a_sel == FWD_EX_MEM) |-> (mem_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_a from x0");
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (fwd_b_sel == FWD_EX_MEM) |-> (mem_rd_addr != 5'd0))
  else $error("hazard_sva: fwd_b from x0");
`endif
endmodule
