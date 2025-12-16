// IronCore Hazard Detection and Forwarding Unit
// Detects data hazards and generates forwarding/stall signals

import ironcore_pkg::*;
module ironcore_hazard (
    // ID stage register addresses (from instruction in ID/EX)
    input logic [REG_ADDR_W-1:0] id_rs1_addr_i,
    input logic [REG_ADDR_W-1:0] id_rs2_addr_i,
    input logic                  id_valid_i,

    // EX stage info (from ID/EX register)
    input logic [REG_ADDR_W-1:0] ex_rd_addr_i,
    input logic                  ex_mem_read_i,
    input logic                  ex_valid_i,
    input logic [REG_ADDR_W-1:0] ex_rs1_addr_i, // Added for forwarding
    input logic [REG_ADDR_W-1:0] ex_rs2_addr_i, // Added for forwarding

    // MEM stage info (from EX/MEM register)
    input logic [REG_ADDR_W-1:0] mem_rd_addr_i,
    input logic                  mem_reg_write_i,
    input logic                  mem_valid_i,

    // WB stage info (from MEM/WB register)
    input logic [REG_ADDR_W-1:0] wb_rd_addr_i,
    input logic                  wb_reg_write_i,
    input logic                  wb_valid_i,

    // Hazard outputs
    output logic load_use_hazard_o,

    // Forwarding outputs (for EX stage operands)
    output ironcore_pkg::fwd_sel_e fwd_a_sel_o,
    output ironcore_pkg::fwd_sel_e fwd_b_sel_o
);

  //--------------------------------------------------------------------------
  // Load-Use Hazard Detection
  //--------------------------------------------------------------------------
  // Stall if EX stage has a load and ID stage needs the result
  // This compares ID stage source regs with EX stage destination
  assign load_use_hazard_o = id_valid_i && ex_valid_i && ex_mem_read_i &&
                              (ex_rd_addr_i != 5'd0) &&
                              ((ex_rd_addr_i == id_rs1_addr_i) ||
                               (ex_rd_addr_i == id_rs2_addr_i));

  //--------------------------------------------------------------------------
  // Forwarding Logic
  //--------------------------------------------------------------------------
  // These signals determine forwarding for the instruction currently in EX stage.
  // The rs1/rs2 addresses passed in are from the ID/EX register (i.e., the
  // instruction in EX stage). We compare against MEM (EX/MEM reg) and WB
  // (MEM/WB reg) to forward results.

  // Note: The caller passes id_ex_reg.rs1_addr and id_ex_reg.rs2_addr to this
  // module as the "id_rs1_addr_i" and "id_rs2_addr_i" inputs for forwarding
  // decisions, and the IF/ID instruction's rs1/rs2 for load-use hazard detection.

  // For RS1 (operand A) forwarding
  always_comb begin
    fwd_a_sel_o = FWD_NONE;

    // Forward from MEM stage (EX/MEM register has result from previous instruction)
    if (mem_valid_i && mem_reg_write_i &&
        (mem_rd_addr_i != 5'd0) &&
        (mem_rd_addr_i == ex_rs1_addr_i)) begin
      fwd_a_sel_o = FWD_EX_MEM;
    end  // Forward from WB stage (MEM/WB register has result from 2 instructions ago)
    else if (wb_valid_i && wb_reg_write_i &&
             (wb_rd_addr_i != 5'd0) &&
             (wb_rd_addr_i == ex_rs1_addr_i)) begin
      fwd_a_sel_o = FWD_MEM_WB;
    end
  end

  //--------------------------------------------------------------------------
  // Forwarding Logic for RS2 (operand B)
  //--------------------------------------------------------------------------
  always_comb begin
    fwd_b_sel_o = FWD_NONE;

    // Forward from MEM stage
    if (mem_valid_i && mem_reg_write_i &&
        (mem_rd_addr_i != 5'd0) &&
        (mem_rd_addr_i == ex_rs2_addr_i)) begin
      fwd_b_sel_o = FWD_EX_MEM;
    end  // Forward from WB stage
    else if (wb_valid_i && wb_reg_write_i &&
             (wb_rd_addr_i != 5'd0) &&
             (wb_rd_addr_i == ex_rs2_addr_i)) begin
      fwd_b_sel_o = FWD_MEM_WB;
    end
  end

endmodule : ironcore_hazard
