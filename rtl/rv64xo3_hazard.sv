// riscv64xO3 Hazard Detection and Forwarding Unit (2-wide)
// Detects data hazards and generates forwarding/stall signals for an
// instruction pair. Producer priority is youngest-first within and across
// stages: EX-B > EX-A > MEM-B > MEM-A > WB-B > WB-A.

import rv64xo3_pkg::*;
module rv64xo3_hazard (
    // ID stage register addresses (IF/ID pair)
    input logic [REG_ADDR_W-1:0] id_a_rs1_addr_i,
    input logic [REG_ADDR_W-1:0] id_a_rs2_addr_i,
    input logic                  id_a_valid_i,
    input logic [REG_ADDR_W-1:0] id_b_rs1_addr_i,
    input logic [REG_ADDR_W-1:0] id_b_rs2_addr_i,
    input logic                  id_b_valid_i,

    // EX stage info (ID/EX pair)
    input logic [REG_ADDR_W-1:0] ex_a_rd_addr_i,
    input logic                  ex_a_mem_read_i,
    input logic                  ex_a_valid_i,
    input logic [REG_ADDR_W-1:0] ex_b_rd_addr_i,
    input logic                  ex_b_mem_read_i,
    input logic                  ex_b_valid_i,
    input logic [REG_ADDR_W-1:0] ex_a_rs1_addr_i,
    input logic [REG_ADDR_W-1:0] ex_a_rs2_addr_i,
    input logic [REG_ADDR_W-1:0] ex_b_rs1_addr_i,
    input logic [REG_ADDR_W-1:0] ex_b_rs2_addr_i,

    // MEM stage info (EX/MEM pair)
    input logic [REG_ADDR_W-1:0] mem_a_rd_addr_i,
    input logic                  mem_a_reg_write_i,
    input logic                  mem_a_valid_i,
    input logic [REG_ADDR_W-1:0] mem_b_rd_addr_i,
    input logic                  mem_b_reg_write_i,
    input logic                  mem_b_valid_i,

    // WB stage info (MEM/WB pair)
    input logic [REG_ADDR_W-1:0] wb_a_rd_addr_i,
    input logic                  wb_a_reg_write_i,
    input logic                  wb_a_valid_i,
    input logic [REG_ADDR_W-1:0] wb_b_rd_addr_i,
    input logic                  wb_b_reg_write_i,
    input logic                  wb_b_valid_i,

    // Hazard outputs
    output logic load_use_hazard_o,

    // Forwarding outputs (per consumer slot)
    output rv64xo3_pkg::fwd_sel_e fwd_a_sel_a_o,
    output rv64xo3_pkg::fwd_sel_e fwd_b_sel_a_o,
    output rv64xo3_pkg::fwd_sel_e fwd_a_sel_b_o,
    output rv64xo3_pkg::fwd_sel_e fwd_b_sel_b_o
);

  //--------------------------------------------------------------------------
  // Load-Use Hazard Detection
  //--------------------------------------------------------------------------
  // Stall if either EX slot holds a load whose destination is needed by
  // either ID slot. Pair-internal load-use (slot-A load, slot-B user in
  // the same ID pair) is handled by dispatch serialize, which issues the
  // load alone so this single-stage check takes over next cycle.
  logic ex_a_load_hit;
  logic ex_b_load_hit;

  assign ex_a_load_hit = ex_a_valid_i && ex_a_mem_read_i &&
                         (ex_a_rd_addr_i != 5'd0) &&
                         ((id_a_valid_i &&
                           ((ex_a_rd_addr_i == id_a_rs1_addr_i) ||
                            (ex_a_rd_addr_i == id_a_rs2_addr_i))) ||
                          (id_b_valid_i &&
                           ((ex_a_rd_addr_i == id_b_rs1_addr_i) ||
                            (ex_a_rd_addr_i == id_b_rs2_addr_i))));

  assign ex_b_load_hit = ex_b_valid_i && ex_b_mem_read_i &&
                         (ex_b_rd_addr_i != 5'd0) &&
                         ((id_a_valid_i &&
                           ((ex_b_rd_addr_i == id_a_rs1_addr_i) ||
                            (ex_b_rd_addr_i == id_a_rs2_addr_i))) ||
                          (id_b_valid_i &&
                           ((ex_b_rd_addr_i == id_b_rs1_addr_i) ||
                            (ex_b_rd_addr_i == id_b_rs2_addr_i))));

  assign load_use_hazard_o = ex_a_load_hit || ex_b_load_hit;

  //--------------------------------------------------------------------------
  // Forwarding Logic (youngest producer wins)
  //--------------------------------------------------------------------------
  // Resolves one consumer register against the older pipeline stages.
  // Only MEM (EX/MEM) and WB (MEM/WB) are producers: an instruction in EX
  // can never source a same-stage consumer (same instruction or younger),
  // so EX rd fields (garbage for stores/branches) must not match here.
  // Priority is youngest-first: MEM-B > MEM-A > WB-B > WB-A. Tags match
  // the EX data muxes (FWD_EX_MEM selects EX/MEM data).
  // NOTE: a load sitting in MEM has not read the bus yet, so its result
  // field holds the address, not data. The pipeline timing (load-use
  // bubble) guarantees a consumer never samples a MEM load in the same
  // cycle it reads the bus; it always sees it one cycle later in WB.
  function automatic rv64xo3_pkg::fwd_sel_e fwd_sel(
    input logic [REG_ADDR_W-1:0] rs_addr,
    input logic                  rs_valid
  );
    begin
      fwd_sel = FWD_NONE;
      if (rs_valid && rs_addr != 5'd0) begin
        if (mem_b_valid_i && mem_b_reg_write_i && (mem_b_rd_addr_i == rs_addr))
          fwd_sel = FWD_EX_B;
        else if (mem_a_valid_i && mem_a_reg_write_i && (mem_a_rd_addr_i == rs_addr))
          fwd_sel = FWD_EX_A;
        else if (wb_b_valid_i && wb_b_reg_write_i && (wb_b_rd_addr_i == rs_addr))
          fwd_sel = FWD_WB_B;
        else if (wb_a_valid_i && wb_a_reg_write_i && (wb_a_rd_addr_i == rs_addr))
          fwd_sel = FWD_WB_A;
      end
    end
  endfunction

  assign fwd_a_sel_a_o = fwd_sel(ex_a_rs1_addr_i, ex_a_valid_i);
  assign fwd_b_sel_a_o = fwd_sel(ex_a_rs2_addr_i, ex_a_valid_i);
  assign fwd_a_sel_b_o = fwd_sel(ex_b_rs1_addr_i, ex_b_valid_i);
  assign fwd_b_sel_b_o = fwd_sel(ex_b_rs2_addr_i, ex_b_valid_i);

endmodule : rv64xo3_hazard
