// riscv64xO3 rename stage (scaffolding toward 2-wide Tomasulo).
// Maps 32 arch regs to PRF_SZ phys regs; checkpoints on branches.
// Not yet wired into rv64xo3_top; interface frozen for bring-up.
import rv64xo3_pkg::*;

module rv64xo3_rename #(
    parameter int PRF_SZ_L = rv64xo3_pkg::PRF_SZ
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    // 2-wide alloc request from decode
    input  logic [1:0] alloc_vld_i,
    input  logic [1:0][4:0] arch_rs1_i,
    input  logic [1:0][4:0] arch_rs2_i,
    input  logic [1:0][4:0] arch_rd_i,
    // phys tags out
    output logic [1:0][$clog2(PRF_SZ_L)-1:0] phys_rs1_o,
    output logic [1:0][$clog2(PRF_SZ_L)-1:0] phys_rs2_o,
    output logic [1:0][$clog2(PRF_SZ_L)-1:0] phys_rd_o,
    output logic stall_o
);
  // Pass-through scaffolding: identity map low bits until freelist lands.
  always_comb begin
    stall_o = 1'b0;
    phys_rs1_o[0] = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rs1_i[0]};
    phys_rs2_o[0] = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rs2_i[0]};
    phys_rd_o[0]  = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rd_i[0]};
    phys_rs1_o[1] = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rs1_i[1]};
    phys_rs2_o[1] = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rs2_i[1]};
    phys_rd_o[1]  = {{($clog2(PRF_SZ_L) - 5) {1'b0}}, arch_rd_i[1]};
  end
endmodule
