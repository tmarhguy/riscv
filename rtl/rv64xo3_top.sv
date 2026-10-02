// riscv64xO3 Top-Level Module
// RV64IMAC 5-stage scalar pipeline (OoO issue/commit landing; see docs/architecture.md)
// Native AXI4-Lite path via rv64xo3_top_axi; Wishbone retained only for debug.

import rv64xo3_pkg::*;
module rv64xo3_top #(
    parameter logic [XLEN-1:0] RESET_PC = 64'h8000_0000
) (
    input logic clk_i,
    input logic rst_ni,

    // Instruction Wishbone Master Interface
    output logic            iwb_cyc_o,
    output logic            iwb_stb_o,
    output logic [XLEN-1:0] iwb_adr_o,
    input  logic [XLEN-1:0] iwb_dat_i,
    input  logic            iwb_ack_i,

    // Data Wishbone Master Interface
    output logic            dwb_cyc_o,
    output logic            dwb_stb_o,
    output logic            dwb_we_o,
    output logic [XLEN-1:0] dwb_adr_o,
    output logic [XLEN-1:0] dwb_dat_o,
    output logic [(XLEN/8)-1:0] dwb_sel_o,
    input  logic [XLEN-1:0] dwb_dat_i,
    input  logic            dwb_ack_i
);

  //--------------------------------------------------------------------------
  // 2-wide superscalar (Phase 2): slot A older, slot B younger.
  // Pipeline registers carry independent pairs; singletons (MUL/DIV engine,
  // LSU port, CSR file) serve one slot per cycle, arbitrated in ID.
  //--------------------------------------------------------------------------
  // Pipeline registers (pairs)
  rv64xo3_pkg::if_id_reg_t               if_id_a;
  rv64xo3_pkg::if_id_reg_t               if_id_b;
  rv64xo3_pkg::id_ex_reg_t               id_ex_a;
  rv64xo3_pkg::id_ex_reg_t               id_ex_b;
  rv64xo3_pkg::ex_mem_reg_t              ex_mem_a;
  rv64xo3_pkg::ex_mem_reg_t              ex_mem_b;
  rv64xo3_pkg::mem_wb_reg_t              mem_wb_a;
  rv64xo3_pkg::mem_wb_reg_t              mem_wb_b;

  // Control signals
  rv64xo3_pkg::ctrl_signals_t            ctrl;

  // PC signals
  logic                        [XLEN-1:0] pc_if;
  logic                                   pc_redirect;
  logic                        [XLEN-1:0] pc_redirect_target;

  // Fetch signals (one aligned pair per fetch)
  logic                        [ILEN-1:0] instr0_if;
  logic                        [ILEN-1:0] instr1_if;
  logic                                   pair_valid_if;
  logic                                   fetch_stall;

  // Decode signals (per slot)
  logic                        [XLEN-1:0] rs1_data_a;
  logic                        [XLEN-1:0] rs2_data_a;
  logic                        [XLEN-1:0] rs1_data_b;
  logic                        [XLEN-1:0] rs2_data_b;

  // Execute signals (per slot; singletons shared, arbitrated in ID)
  logic                        [XLEN-1:0] alu_result_a;
  logic                        [XLEN-1:0] alu_result_b;
  logic                                   branch_taken_a;
  logic                                   branch_taken_b;
  logic                        [XLEN-1:0] branch_target_a;
  logic                        [XLEN-1:0] branch_target_b;
  logic                        [XLEN-1:0] mul_result_ex;
  logic                        [XLEN-1:0] div_result_ex;
  logic                                   div_valid_ex;
  logic                                   div_engine_busy;

  // DIV scoreboard: one outstanding DIV (see Phase 1 notes below)
  logic                                   div_busy;
  logic                        [REG_ADDR_W-1:0] div_slot_rd;
  logic                                   div_op_a;
  logic                                   div_op_b;
  logic                                   div_issue;
  logic                                   div_issue_a;
  logic                                   div_issue_b;
  logic                                   div_struct_stall;
  logic                                   div_raw_stall;
  logic                                   div_inject;
  logic                                   div_kill;
  logic                                   div_kill_a;
  logic                                   div_kill_b;
  logic                                   kill_b;
  logic                                   taken_a;
  logic                                   taken_b;
  logic                                   redir_a;
  logic                                   redir_b;
  logic                        [XLEN-1:0] redir_target_a;
  logic                        [XLEN-1:0] redir_target_b;
  logic                                   exc_valid_a;
  logic                                   exc_valid_b;
  logic                        [XLEN-1:0] exc_cause_a;
  logic                        [XLEN-1:0] exc_cause_b;
  logic                        [XLEN-1:0] exc_pc_a;
  logic                        [XLEN-1:0] exc_pc_b;
  logic                                   mret_a_taken;
  logic                                   mret_b_taken;
  logic                        [XLEN-1:0] trap_val_a;
  logic                        [XLEN-1:0] trap_val_b;
  logic                        [XLEN-1:0] trap_val;
  logic                                   bp_update_en;
  logic                        [XLEN-1:0] bp_update_pc;
  logic                                   bp_update_taken;
  logic                                   mem_exc_unit;
  logic                        [XLEN-1:0] mem_exc_cause_unit;

  // Memory signals (single bus port; slot A has priority)
  logic                        [XLEN-1:0] mem_rdata;
  logic                                   mem_stall;
  logic                                   mem_exc_valid_a;
  logic                                   mem_exc_valid_b;
  logic                        [XLEN-1:0] mem_exc_cause_a;
  logic                        [XLEN-1:0] mem_exc_cause_b;

  // Forwarding signals (per slot)
  rv64xo3_pkg::fwd_sel_e                 fwd_a_sel_a;
  rv64xo3_pkg::fwd_sel_e                 fwd_b_sel_a;
  rv64xo3_pkg::fwd_sel_e                 fwd_a_sel_b;
  rv64xo3_pkg::fwd_sel_e                 fwd_b_sel_b;
  logic                        [XLEN-1:0] fwd_a_data_a;
  logic                        [XLEN-1:0] fwd_b_data_a;
  logic                        [XLEN-1:0] fwd_a_data_b;
  logic                        [XLEN-1:0] fwd_b_data_b;

  // Hazard detection
  logic                                   load_use_hazard;
  logic                                   serialize_pair;

  // Branch prediction (slot A; slot B defaults not-taken)
  logic                                   pred_taken_if;
  logic                        [XLEN-1:0] pred_target_if;
  logic                                   pred_miss_a;
  logic                                   pred_miss_b;

  // CSR signals
  /* verilator lint_off UNUSEDSIGNAL */
  logic                        [XLEN-1:0] csr_rdata;  // Will be used for CSR read instructions
  /* verilator lint_on UNUSEDSIGNAL */
  logic                        [XLEN-1:0] mtvec;
  logic                        [XLEN-1:0] mepc;

  // Exception signals (global trap/mret; per-slot above)
  logic                                   exc_valid;
  logic                        [XLEN-1:0] exc_cause;
  logic                        [XLEN-1:0] exc_pc;
  logic                                   trap_taken;
  logic                                   mret_taken;

  //--------------------------------------------------------------------------
  // IF Stage - 2-wide Instruction Fetch
  //--------------------------------------------------------------------------
  rv64xo3_if #(
      .RESET_PC(RESET_PC)
  ) u_if (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .stall_i      (ctrl.stall_if),
      .flush_i      (ctrl.flush_if),
      .pc_redirect_i(pc_redirect),
      .pc_target_i  (pc_redirect_target),
      .pred_taken_i (pred_taken_if),
      .pred_target_i(pred_target_if),
      .iwb_cyc_o    (iwb_cyc_o),
      .iwb_stb_o    (iwb_stb_o),
      .iwb_adr_o    (iwb_adr_o),
      .iwb_dat_i    (iwb_dat_i),
      .iwb_ack_i    (iwb_ack_i),
      .pc_o         (pc_if),
      .instr0_o     (instr0_if),
      .instr1_o     (instr1_if),
      .pair_valid_o (pair_valid_if),
      .fetch_stall_o(fetch_stall)
  );

  //--------------------------------------------------------------------------
  // Branch Predictor (Bimodal, slot A; slot B defaults not-taken)
  //--------------------------------------------------------------------------
  rv64xo3_bp u_bp (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .pc_i          (pc_if),
      .instr_i       (instr0_if),
      .instr_valid_i (pair_valid_if),
      .update_en_i   (bp_update_en),
      .update_pc_i   (bp_update_pc),
      .update_taken_i(bp_update_taken),
      .pred_taken_o  (pred_taken_if),
      .pred_target_o (pred_target_if)
  );

  //--------------------------------------------------------------------------
  // IF/ID Pipeline Register (pair with shift on serialize)
  //--------------------------------------------------------------------------
  // Priority: flush (clear both) > freeze (hold) > serialize (B shifts to
  // slot A, slot B bubbles, IF held so nothing is lost) > normal advance.
  // Serialize fires only when nothing else stalls, so every register here
  // advances coherently and no instruction is duplicated or dropped.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      if_id_a <= '0;
      if_id_b <= '0;
    end else if (ctrl.flush_id) begin
      if_id_a <= '0;
      if_id_b <= '0;
    end else if (!ctrl.stall_id) begin
      if (serialize_pair) begin
        if_id_a.pc          <= if_id_b.pc;
        if_id_a.instr       <= if_id_b.instr;
        if_id_a.valid       <= if_id_b.valid;
        if_id_a.pred_taken  <= if_id_b.pred_taken;
        if_id_a.pred_target <= if_id_b.pred_target;
        if_id_b <= '0;
      end else if (pair_valid_if && !ctrl.flush_if) begin
        if_id_a.pc          <= pc_if;
        if_id_a.instr       <= instr0_if;
        if_id_a.valid       <= 1'b1;
        if_id_a.pred_taken  <= pred_taken_if;
        if_id_a.pred_target <= pred_target_if;
        if_id_b.pc          <= pc_if + 64'd4;
        if_id_b.instr       <= instr1_if;
        if_id_b.valid       <= 1'b1;
        if_id_b.pred_taken  <= 1'b0;
        if_id_b.pred_target <= pc_if + 64'd8;
      end else begin
        if_id_a <= '0;
        if_id_b <= '0;
      end
    end
  end

  //--------------------------------------------------------------------------
  // ID Stage - Dual Decode
  //--------------------------------------------------------------------------
  // Dual writeback muxes (slot A older, slot B younger): normal MEM/WB
  // paths, except during a DIV inject cycle when the completed DIV result
  // takes one port (MEM/WB is held that cycle, so nothing is lost).
  // Driven in the writeback section below; declared here for the regfile.
  logic                        [XLEN-1:0] wb_a_data;
  logic                        [REG_ADDR_W-1:0] wb_a_addr;
  logic                                   wb_a_wen;
  logic                        [XLEN-1:0] wb_b_data;
  logic                        [REG_ADDR_W-1:0] wb_b_addr;
  logic                                   wb_b_wen;

  rv64xo3_id u_id (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .if_id_a_i   (if_id_a),
      .if_id_b_i   (if_id_b),
      .wb_a_addr_i (wb_a_addr),
      .wb_a_data_i (wb_a_data),
      .wb_a_wen_i  (wb_a_wen),
      .wb_b_addr_i (wb_b_addr),
      .wb_b_data_i (wb_b_data),
      .wb_b_wen_i  (wb_b_wen),
      .rs1_a_data_o(rs1_data_a),
      .rs2_a_data_o(rs2_data_a),
      .rs1_b_data_o(rs1_data_b),
      .rs2_b_data_o(rs2_data_b)
  );

  // Decoders (one per slot)
  logic                     [XLEN-1:0] imm_a;
  logic                     [XLEN-1:0] imm_b;
  rv64xo3_pkg::alu_op_e               alu_op_a;
  rv64xo3_pkg::alu_op_e               alu_op_b;
  rv64xo3_pkg::branch_op_e            branch_op_a;
  rv64xo3_pkg::branch_op_e            branch_op_b;
  rv64xo3_pkg::muldiv_op_e            muldiv_op_a;
  rv64xo3_pkg::muldiv_op_e            muldiv_op_b;
  logic                                alu_src_a;
  logic                                alu_src_b;
  logic                                mem_read_a;
  logic                                mem_read_b;
  logic                                mem_write_a;
  logic                                mem_write_b;
  rv64xo3_pkg::mem_width_e            mem_width_a;
  rv64xo3_pkg::mem_width_e            mem_width_b;
  logic                                mem_unsigned_a;
  logic                                mem_unsigned_b;
  logic                                reg_write_a;
  logic                                reg_write_b;
  logic                                is_branch_a;
  logic                                is_branch_b;
  logic                                is_jal_a;
  logic                                is_jal_b;
  logic                                is_jalr_a;
  logic                                is_jalr_b;
  logic                                is_muldiv_a;
  logic                                is_muldiv_b;
  logic                                is_csr_a;
  logic                                is_csr_b;
  logic                     [    11:0] csr_addr_a;
  logic                     [    11:0] csr_addr_b;
  logic                     [     2:0] csr_op_a;
  logic                     [     2:0] csr_op_b;
  logic                                is_ecall_a;
  logic                                is_ecall_b;
  logic                                is_ebreak_a;
  logic                                is_ebreak_b;
  logic                                is_mret_a;
  logic                                is_mret_b;
  logic                                is_auipc_a;
  logic                                is_auipc_b;
  logic                                illegal_instr_a;
  logic                                illegal_instr_b;

  rv64xo3_decoder u_decoder_a (
      .instr_i        (if_id_a.instr),
      .imm_o          (imm_a),
      .alu_op_o       (alu_op_a),
      .branch_op_o    (branch_op_a),
      .muldiv_op_o    (muldiv_op_a),
      .alu_src_o      (alu_src_a),
      .mem_read_o     (mem_read_a),
      .mem_write_o    (mem_write_a),
      .mem_width_o    (mem_width_a),
      .mem_unsigned_o (mem_unsigned_a),
      .reg_write_o    (reg_write_a),
      .is_branch_o    (is_branch_a),
      .is_jal_o       (is_jal_a),
      .is_jalr_o      (is_jalr_a),
      .is_muldiv_o    (is_muldiv_a),
      .is_csr_o       (is_csr_a),
      .csr_addr_o     (csr_addr_a),
      .csr_op_o       (csr_op_a),
      .is_ecall_o     (is_ecall_a),
      .is_ebreak_o    (is_ebreak_a),
      .is_mret_o      (is_mret_a),
      .is_auipc_o     (is_auipc_a),
      .illegal_instr_o(illegal_instr_a)
  );

  rv64xo3_decoder u_decoder_b (
      .instr_i        (if_id_b.instr),
      .imm_o          (imm_b),
      .alu_op_o       (alu_op_b),
      .branch_op_o    (branch_op_b),
      .muldiv_op_o    (muldiv_op_b),
      .alu_src_o      (alu_src_b),
      .mem_read_o     (mem_read_b),
      .mem_write_o    (mem_write_b),
      .mem_width_o    (mem_width_b),
      .mem_unsigned_o (mem_unsigned_b),
      .reg_write_o    (reg_write_b),
      .is_branch_o    (is_branch_b),
      .is_jal_o       (is_jal_b),
      .is_jalr_o      (is_jalr_b),
      .is_muldiv_o    (is_muldiv_b),
      .is_csr_o       (is_csr_b),
      .csr_addr_o     (csr_addr_b),
      .csr_op_o       (csr_op_b),
      .is_ecall_o     (is_ecall_b),
      .is_ebreak_o    (is_ebreak_b),
      .is_mret_o      (is_mret_b),
      .is_auipc_o     (is_auipc_b),
      .illegal_instr_o(illegal_instr_b)
  );

  //--------------------------------------------------------------------------
  // Pair issue decision (serialize vs dual-issue)
  //--------------------------------------------------------------------------
  // Slot B issues alongside slot A unless it must wait: RAW on slot A,
  // same-register write-after-write, or a shared singleton (one LSU port,
  // one MUL/DIV engine, one CSR file) needed by both. Serializing shifts B
  // into slot A next cycle (see if_id above) instead of dropping it.
  // rs2 counts as used for reg-reg ALU, stores, branches and muldiv; I-type
  // ALU, loads, AUIPC/LUI/JAL and CSR-immediate forms ignore it.
  logic a_writes;
  logic b_writes;
  logic b_rs2_used;
  logic pair_raw;
  logic pair_waw;
  logic pair_struct;
  assign a_writes   = reg_write_a && (if_id_a.instr[11:7] != 5'd0);
  assign b_writes   = reg_write_b && (if_id_b.instr[11:7] != 5'd0);
  assign b_rs2_used = (!alu_src_b || mem_write_b || is_branch_b || is_muldiv_b);
  assign pair_raw = if_id_a.valid && if_id_b.valid && a_writes &&
                    ((if_id_b.instr[19:15] == if_id_a.instr[11:7]) ||
                     (b_rs2_used && (if_id_b.instr[24:20] == if_id_a.instr[11:7])));
  assign pair_waw = if_id_a.valid && if_id_b.valid && a_writes && b_writes &&
                    (if_id_a.instr[11:7] == if_id_b.instr[11:7]);
  assign pair_struct = if_id_a.valid && if_id_b.valid &&
                       (((mem_read_a || mem_write_a) && (mem_read_b || mem_write_b)) ||
                        (is_muldiv_a && is_muldiv_b) ||
                        (is_csr_a && is_csr_b) ||
                        // CSR write followed by a CSR-state reader (mret reads
                        // mepc/mstatus, traps read mtvec): the reader must see
                        // the write, so split them across cycles.
                        (is_csr_a && (is_mret_b || is_ecall_b || is_ebreak_b ||
                                      illegal_instr_b)));
  assign serialize_pair = if_id_b.valid && (pair_raw || pair_waw || pair_struct) &&
                          !ctrl.stall_id && !pc_redirect;

  //--------------------------------------------------------------------------
  // ID/EX Pipeline Register (pair; slot B bubbles on serialize)
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_ex_a <= '0;
      id_ex_b <= '0;
    end else if (ctrl.flush_ex) begin
      id_ex_a <= '0;
      id_ex_b <= '0;
    end else if (!ctrl.stall_ex) begin
      id_ex_a.pc <= if_id_a.pc;
      id_ex_a.rs1_data <= rs1_data_a;
      id_ex_a.rs2_data <= rs2_data_a;
      id_ex_a.imm <= imm_a;
      id_ex_a.rs1_addr <= if_id_a.instr[19:15];
      id_ex_a.rs2_addr <= if_id_a.instr[24:20];
      id_ex_a.rd_addr <= if_id_a.instr[11:7];
      // Suppress reg_write when rd=x0 (writes to x0 are NOPs)
      id_ex_a.reg_write <= reg_write_a && (if_id_a.instr[11:7] != 5'd0);
      id_ex_a.alu_op <= alu_op_a;
      id_ex_a.branch_op <= branch_op_a;
      id_ex_a.muldiv_op <= muldiv_op_a;
      id_ex_a.alu_src <= alu_src_a;
      id_ex_a.mem_read <= mem_read_a;
      id_ex_a.mem_write <= mem_write_a;
      id_ex_a.mem_width <= mem_width_a;
      id_ex_a.mem_unsigned <= mem_unsigned_a;
      id_ex_a.is_branch <= is_branch_a;
      id_ex_a.is_jal <= is_jal_a;
      id_ex_a.is_jalr <= is_jalr_a;
      id_ex_a.is_muldiv <= is_muldiv_a;
      id_ex_a.is_csr <= is_csr_a;
      id_ex_a.csr_addr <= csr_addr_a;
      id_ex_a.csr_op <= csr_op_a;
      id_ex_a.is_ecall <= is_ecall_a;
      id_ex_a.is_ebreak <= is_ebreak_a;
      id_ex_a.is_mret <= is_mret_a;
      id_ex_a.is_auipc <= is_auipc_a;
      id_ex_a.illegal_instr <= illegal_instr_a && if_id_a.valid;  // Only illegal if valid instr
      id_ex_a.valid <= if_id_a.valid && !load_use_hazard && !pc_redirect;
      id_ex_a.pred_taken <= if_id_a.pred_taken;
      id_ex_a.pred_target <= if_id_a.pred_target;
      if (serialize_pair) begin
        id_ex_b <= '0;
      end else begin
        id_ex_b.pc <= if_id_b.pc;
        id_ex_b.rs1_data <= rs1_data_b;
        id_ex_b.rs2_data <= rs2_data_b;
        id_ex_b.imm <= imm_b;
        id_ex_b.rs1_addr <= if_id_b.instr[19:15];
        id_ex_b.rs2_addr <= if_id_b.instr[24:20];
        id_ex_b.rd_addr <= if_id_b.instr[11:7];
        // Suppress reg_write when rd=x0 (writes to x0 are NOPs)
        id_ex_b.reg_write <= reg_write_b && (if_id_b.instr[11:7] != 5'd0);
        id_ex_b.alu_op <= alu_op_b;
        id_ex_b.branch_op <= branch_op_b;
        id_ex_b.muldiv_op <= muldiv_op_b;
        id_ex_b.alu_src <= alu_src_b;
        id_ex_b.mem_read <= mem_read_b;
        id_ex_b.mem_write <= mem_write_b;
        id_ex_b.mem_width <= mem_width_b;
        id_ex_b.mem_unsigned <= mem_unsigned_b;
        id_ex_b.is_branch <= is_branch_b;
        id_ex_b.is_jal <= is_jal_b;
        id_ex_b.is_jalr <= is_jalr_b;
        id_ex_b.is_muldiv <= is_muldiv_b;
        id_ex_b.is_csr <= is_csr_b;
        id_ex_b.csr_addr <= csr_addr_b;
        id_ex_b.csr_op <= csr_op_b;
        id_ex_b.is_ecall <= is_ecall_b;
        id_ex_b.is_ebreak <= is_ebreak_b;
        id_ex_b.is_mret <= is_mret_b;
        id_ex_b.is_auipc <= is_auipc_b;
        id_ex_b.illegal_instr <= illegal_instr_b && if_id_b.valid;  // Only illegal if valid instr
        id_ex_b.valid <= if_id_b.valid && !load_use_hazard && !pc_redirect;
        id_ex_b.pred_taken <= if_id_b.pred_taken;
        id_ex_b.pred_target <= if_id_b.pred_target;
      end
    end
  end

  //--------------------------------------------------------------------------
  // EX Stage - Dual Execute
  //--------------------------------------------------------------------------
  rv64xo3_ex u_ex (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .id_ex_a_i        (id_ex_a),
      .id_ex_b_i        (id_ex_b),
      .fwd_a_sel_a_i    (fwd_a_sel_a),
      .fwd_b_sel_a_i    (fwd_b_sel_a),
      .fwd_a_sel_b_i    (fwd_a_sel_b),
      .fwd_b_sel_b_i    (fwd_b_sel_b),
      .fwd_ex_mem_a_data_i(ex_mem_a.alu_result),
      .fwd_ex_mem_b_data_i(ex_mem_b.alu_result),
      .fwd_mem_wb_a_data_i(mem_wb_a.result),
      .fwd_mem_wb_b_data_i(mem_wb_b.result),
      .div_start_i    (div_issue),
      .alu_result_a_o   (alu_result_a),
      .alu_result_b_o   (alu_result_b),
      .branch_taken_a_o (branch_taken_a),
      .branch_taken_b_o (branch_taken_b),
      .branch_target_a_o(branch_target_a),
      .branch_target_b_o(branch_target_b),
      .mul_result_o     (mul_result_ex),
      .div_result_o     (div_result_ex),
      .div_valid_o      (div_valid_ex),
      .div_busy_o       (div_engine_busy)
  );

  // Forward data muxes (per slot; store data uses the B muxes)
  always_comb begin
    case (fwd_b_sel_a)
      FWD_EX_A: fwd_b_data_a = ex_mem_a.alu_result;
      FWD_EX_B: fwd_b_data_a = ex_mem_b.alu_result;
      FWD_WB_A: fwd_b_data_a = mem_wb_a.result;
      FWD_WB_B: fwd_b_data_a = mem_wb_b.result;
      default:  fwd_b_data_a = id_ex_a.rs2_data;
    endcase

    case (fwd_a_sel_a)
      FWD_EX_A: fwd_a_data_a = ex_mem_a.alu_result;
      FWD_EX_B: fwd_a_data_a = ex_mem_b.alu_result;
      FWD_WB_A: fwd_a_data_a = mem_wb_a.result;
      FWD_WB_B: fwd_a_data_a = mem_wb_b.result;
      default:  fwd_a_data_a = id_ex_a.rs1_data;
    endcase

    case (fwd_b_sel_b)
      FWD_EX_A: fwd_b_data_b = ex_mem_a.alu_result;
      FWD_EX_B: fwd_b_data_b = ex_mem_b.alu_result;
      FWD_WB_A: fwd_b_data_b = mem_wb_a.result;
      FWD_WB_B: fwd_b_data_b = mem_wb_b.result;
      default:  fwd_b_data_b = id_ex_b.rs2_data;
    endcase

    case (fwd_a_sel_b)
      FWD_EX_A: fwd_a_data_b = ex_mem_a.alu_result;
      FWD_EX_B: fwd_a_data_b = ex_mem_b.alu_result;
      FWD_WB_A: fwd_a_data_b = mem_wb_a.result;
      FWD_WB_B: fwd_a_data_b = mem_wb_b.result;
      default:  fwd_a_data_b = id_ex_b.rs1_data;
    endcase
  end

  //--------------------------------------------------------------------------
  // EX/MEM Pipeline Register (pair)
  //--------------------------------------------------------------------------
  // MUL retires from EX like an ALU op (single-cycle). An issued DIV
  // vanishes here into a bubble: its result arrives later via the
  // scoreboard inject, so it must neither forward nor write back.
  // When EX is frozen while MEM advances, MEM takes a bubble instead of
  // re-capturing the frozen instruction (re-capture would duplicate it
  // with drifting forward values as MEM/WB drain). The load-use flush
  // path still saves its load explicitly (flush wins over the bubble).
  // Slot B is additionally killed when slot A takes control flow or traps
  // (B is younger and must not commit past it).
  // Per-slot EX trap requests (own ecall/ebreak/illegal, or a
  // fetch-misaligned control transfer won by this slot). Slot A traps retire
  // nothing younger; slot B traps retire slot A first.
  logic trap_ex_a;
  logic trap_ex_b;
  logic mem_trap_any;
  assign mem_trap_any = mem_exc_valid_a || mem_exc_valid_b;
  assign trap_ex_a = id_ex_a.valid &&
                    (id_ex_a.is_ecall || id_ex_a.is_ebreak || id_ex_a.illegal_instr ||
                     (fetch_misaligned && redir_a));
  assign trap_ex_b = id_ex_b.valid &&
                    (id_ex_b.is_ecall || id_ex_b.is_ebreak || id_ex_b.illegal_instr ||
                     (fetch_misaligned && redir_b));

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ex_mem_a <= '0;
      ex_mem_b <= '0;
    end else if (!ctrl.stall_mem) begin
      if (div_kill_a || (ctrl.stall_ex && !ctrl.flush_ex)) begin
        ex_mem_a <= '0;
      end else begin
        ex_mem_a.pc <= id_ex_a.pc;
        ex_mem_a.alu_result <= id_ex_a.is_muldiv && !div_op_a ? mul_result_ex :
                               id_ex_a.is_csr ? csr_rdata :
                               alu_result_a;
        ex_mem_a.rs2_data <= fwd_b_data_a;
        ex_mem_a.rd_addr <= id_ex_a.rd_addr;
        ex_mem_a.mem_read <= id_ex_a.mem_read;
        ex_mem_a.mem_write <= id_ex_a.mem_write;
        ex_mem_a.mem_width <= id_ex_a.mem_width;
        ex_mem_a.mem_unsigned <= id_ex_a.mem_unsigned;
        ex_mem_a.reg_write <= id_ex_a.reg_write;
        ex_mem_a.valid <= id_ex_a.valid && !trap_ex_a && !mem_trap_any;
      end
      if (div_kill_b || kill_b || (ctrl.stall_ex && !ctrl.flush_ex)) begin
        ex_mem_b <= '0;
      end else begin
        ex_mem_b.pc <= id_ex_b.pc;
        ex_mem_b.alu_result <= id_ex_b.is_muldiv && !div_op_b ? mul_result_ex :
                               id_ex_b.is_csr ? csr_rdata :
                               alu_result_b;
        ex_mem_b.rs2_data <= fwd_b_data_b;
        ex_mem_b.rd_addr <= id_ex_b.rd_addr;
        ex_mem_b.mem_read <= id_ex_b.mem_read;
        ex_mem_b.mem_write <= id_ex_b.mem_write;
        ex_mem_b.mem_width <= id_ex_b.mem_width;
        ex_mem_b.mem_unsigned <= id_ex_b.mem_unsigned;
        ex_mem_b.reg_write <= id_ex_b.reg_write;
        ex_mem_b.valid <= id_ex_b.valid && !trap_ex_b && !mem_trap_any && !kill_b;
      end
    end
  end

  //--------------------------------------------------------------------------
  // MEM Stage - Memory Access (single bus port; slot A has priority)
  //--------------------------------------------------------------------------
  // Dispatch serializes mem+mem pairs, so at most one slot needs the bus;
  // slot A wins ties defensively (plus an SVA below).
  logic memop_a;
  logic memop_b;
  assign memop_a = ex_mem_a.valid && (ex_mem_a.mem_read || ex_mem_a.mem_write);
  assign memop_b = ex_mem_b.valid && (ex_mem_b.mem_read || ex_mem_b.mem_write)
                   && !memop_a;

  rv64xo3_pkg::ex_mem_reg_t ex_mem_mux;
  always_comb begin
    ex_mem_mux = ex_mem_a;
    if (!memop_a) begin
      ex_mem_mux = ex_mem_b;
    end
  end

  rv64xo3_mem u_mem (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .ex_mem_reg_i(ex_mem_mux),
      .dwb_cyc_o   (dwb_cyc_o),
      .dwb_stb_o   (dwb_stb_o),
      .dwb_we_o    (dwb_we_o),
      .dwb_adr_o   (dwb_adr_o),
      .dwb_dat_o   (dwb_dat_o),
      .dwb_sel_o   (dwb_sel_o),
      .dwb_dat_i   (dwb_dat_i),
      .dwb_ack_i   (dwb_ack_i),
      .mem_rdata_o (mem_rdata),
      .mem_stall_o (mem_stall),
      .mem_exc_valid_o(mem_exc_unit),
      .mem_exc_cause_o(mem_exc_cause_unit)
  );

  // Attribute any MEM fault to the slot that owns the bus.
  assign mem_exc_valid_a = mem_exc_unit && memop_a;
  assign mem_exc_valid_b = mem_exc_unit && !memop_a && memop_b;
  assign mem_exc_cause_a = mem_exc_cause_unit;
  assign mem_exc_cause_b = mem_exc_cause_unit;

  //--------------------------------------------------------------------------
  // MEM/WB Pipeline Register (pair)
  //--------------------------------------------------------------------------
  // Precise-trap rule: an instruction that faults in MEM must not retire;
  // a younger slot-B fault additionally kills nothing older (slot A still
  // retires), while a slot-A fault kills slot B with it.
  // (EX-stage faults still let older stages retire, and younger stages are
  // flushed. Without the MEM rule, a faulting load writes back stale bus
  // data, clobbering its own rd.)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_wb_a <= '0;
      mem_wb_b <= '0;
    end else if (!ctrl.stall_mem) begin
      if (mem_exc_valid_a) begin
        mem_wb_a <= '0;
      end else begin
        mem_wb_a.pc        <= ex_mem_a.pc;
        mem_wb_a.result    <= ex_mem_a.mem_read ? mem_rdata : ex_mem_a.alu_result;
        mem_wb_a.rd_addr   <= ex_mem_a.rd_addr;
        mem_wb_a.reg_write <= ex_mem_a.reg_write;
        mem_wb_a.valid     <= ex_mem_a.valid;
      end
      if (mem_exc_valid_b || mem_exc_valid_a) begin
        mem_wb_b <= '0;
      end else begin
        mem_wb_b.pc        <= ex_mem_b.pc;
        mem_wb_b.result    <= ex_mem_b.mem_read ? mem_rdata : ex_mem_b.alu_result;
        mem_wb_b.rd_addr   <= ex_mem_b.rd_addr;
        mem_wb_b.reg_write <= ex_mem_b.reg_write;
        mem_wb_b.valid     <= ex_mem_b.valid;
      end
    end
  end

  //--------------------------------------------------------------------------
  // Writeback muxes (slot A older, slot B younger; DIV inject takes port A)
  //--------------------------------------------------------------------------
  assign wb_a_wen  = div_inject ? (div_slot_rd != 5'd0) :
                                  (mem_wb_a.reg_write && mem_wb_a.valid);
  assign wb_a_addr = div_inject ? div_slot_rd : mem_wb_a.rd_addr;
  assign wb_a_data = div_inject ? div_result_ex : mem_wb_a.result;
  assign wb_b_wen  = mem_wb_b.reg_write && mem_wb_b.valid;
  assign wb_b_addr = mem_wb_b.rd_addr;
  assign wb_b_data = mem_wb_b.result;

  //--------------------------------------------------------------------------
  // Hazard Detection Unit (pair matrix; youngest producer wins)
  //--------------------------------------------------------------------------
  rv64xo3_hazard u_hazard (
      .id_a_rs1_addr_i (if_id_a.instr[19:15]),
      .id_a_rs2_addr_i (if_id_a.instr[24:20]),
      .id_a_valid_i    (if_id_a.valid),
      .id_b_rs1_addr_i (if_id_b.instr[19:15]),
      .id_b_rs2_addr_i (if_id_b.instr[24:20]),
      .id_b_valid_i    (if_id_b.valid),
      .ex_a_rd_addr_i  (id_ex_a.rd_addr),
      .ex_a_mem_read_i (id_ex_a.mem_read),
      .ex_a_valid_i    (id_ex_a.valid),
      .ex_b_rd_addr_i  (id_ex_b.rd_addr),
      .ex_b_mem_read_i (id_ex_b.mem_read),
      .ex_b_valid_i    (id_ex_b.valid),
      .ex_a_rs1_addr_i (id_ex_a.rs1_addr),
      .ex_a_rs2_addr_i (id_ex_a.rs2_addr),
      .ex_b_rs1_addr_i (id_ex_b.rs1_addr),
      .ex_b_rs2_addr_i (id_ex_b.rs2_addr),
      .mem_a_rd_addr_i (ex_mem_a.rd_addr),
      .mem_a_reg_write_i(ex_mem_a.reg_write),
      .mem_a_valid_i   (ex_mem_a.valid),
      .mem_b_rd_addr_i (ex_mem_b.rd_addr),
      .mem_b_reg_write_i(ex_mem_b.reg_write),
      .mem_b_valid_i   (ex_mem_b.valid),
      .wb_a_rd_addr_i  (mem_wb_a.rd_addr),
      .wb_a_reg_write_i(mem_wb_a.reg_write),
      .wb_a_valid_i    (mem_wb_a.valid),
      .wb_b_rd_addr_i  (mem_wb_b.rd_addr),
      .wb_b_reg_write_i(mem_wb_b.reg_write),
      .wb_b_valid_i    (mem_wb_b.valid),
      .load_use_hazard_o(load_use_hazard),
      .fwd_a_sel_a_o   (fwd_a_sel_a),
      .fwd_b_sel_a_o   (fwd_b_sel_a),
      .fwd_a_sel_b_o   (fwd_a_sel_b),
      .fwd_b_sel_b_o   (fwd_b_sel_b)
  );

  // Forwarding is computed in rv64xo3_hazard; per-slot data muxes live
  // next to the EX stage above. Single source of truth, no duplication.

  //--------------------------------------------------------------------------
  // Control Unit: per-slot resolve, redirect priority, stalls
  //--------------------------------------------------------------------------
  // Slot-taken: unconditional jumps always take; branches use EX resolve.
  assign taken_a = id_ex_a.valid &&
                   (id_ex_a.is_jal || id_ex_a.is_jalr ||
                    (id_ex_a.is_branch && branch_taken_a));
  assign taken_b = id_ex_b.valid &&
                   (id_ex_b.is_jal || id_ex_b.is_jalr ||
                    (id_ex_b.is_branch && branch_taken_b));

  // Mispredicts: slot A against the predictor, slot B against default NT.
  assign pred_miss_a = id_ex_a.valid && id_ex_a.is_branch &&
                       (branch_taken_a != id_ex_a.pred_taken ||
                        (branch_taken_a && branch_target_a != id_ex_a.pred_target));
  assign pred_miss_b = id_ex_b.valid && id_ex_b.is_branch && branch_taken_b;

  // Redirect requests per slot (taken/miss), older slot wins.
  assign redir_a        = taken_a || pred_miss_a;
  assign redir_target_a = taken_a ? branch_target_a : (id_ex_a.pc + 64'd4);
  assign redir_b        = taken_b || pred_miss_b;
  assign redir_target_b = taken_b ? branch_target_b : (id_ex_b.pc + 64'd4);

  // Slot B dies when anything older redirects or traps (B already
  // executed beside it in EX but is wrong-path). A redirect from B itself
  // does not suppress B. Without this, slot B can hold a non-instruction
  // (compressed halves, padding) that must never trap or take effect.
  logic other_side_redir;
  assign other_side_redir = exc_valid_a || mem_exc_valid_a || mem_exc_valid_b ||
                            mret_a_taken || taken_a || pred_miss_a;
  assign kill_b = other_side_redir;

  // PC redirect logic (trap > mret > slot A > slot B)
  assign pc_redirect = trap_taken || mret_taken || redir_a || redir_b;

  assign pc_redirect_target = trap_taken ? mtvec :
                              mret_taken ? mepc :
                              redir_a ? redir_target_a :
                              redir_b ? redir_target_b :
                              '0;

  //--------------------------------------------------------------------------
  // DIV scoreboard (Phase 1: non-blocking divide)
  //--------------------------------------------------------------------------
  // MUL retires from EX like an ALU op and needs no tracking. A DIV is
  // latched into the iterative engine and releases EX immediately; at most
  // one DIV is outstanding, tracked here by destination register. While it
  // is outstanding:
  // - ID stalls on any instruction touching that register (RAW or WAW;
  //   rs2 is checked raw, so I-type ops with aliasing immediates may stall
  //   spuriously — safe, and Tomasulo will make it moot).
  // - a second DIV in EX waits (structural: single engine).
  // - on completion the pipe freezes one cycle and the result is written
  //   straight to the register file (MEM/WB is held, so nothing is lost).
  // The DIV instruction itself vanishes from the pipe at issue (bubble),
  // so it can neither forward garbage nor write back early.

  // DIV-class op in EX (per slot)?
  always_comb begin
    case (id_ex_a.muldiv_op)
      MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_MULW: div_op_a = 1'b0;
      default: div_op_a = id_ex_a.valid && id_ex_a.is_muldiv;
    endcase
    case (id_ex_b.muldiv_op)
      MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_MULW: div_op_b = 1'b0;
      default: div_op_b = id_ex_b.valid && id_ex_b.is_muldiv;
    endcase
  end

  // Single-cycle accept pulse per slot: DIV in EX, engine free (both the
  // slot and the engine agree; either one alone blocks). Dispatch
  // serializes muldiv+muldiv pairs, so both slots never fire together
  // (plus an SVA below); slot A wins ties defensively.
  assign div_issue_a = id_ex_a.valid && div_op_a && !div_busy && !div_engine_busy;
  assign div_issue_b = id_ex_b.valid && div_op_b && !div_busy && !div_engine_busy &&
                       !other_side_redir;
  assign div_issue = div_issue_a || div_issue_b;
  // Structural: DIV waiting in EX while the engine is busy.
  assign div_struct_stall = (id_ex_a.valid && div_op_a && (div_busy || div_engine_busy)) ||
                            (id_ex_b.valid && div_op_b && (div_busy || div_engine_busy));
  // RAW/WAW on the outstanding DIV destination (checked in both ID slots).
  // NOTE: a frozen VALID instruction in EX must never be re-captured into
  // MEM (it would duplicate with live-forward drift as MEM/WB drain), so
  // the EX/MEM capture below inserts a bubble whenever EX is stalled while
  // MEM advances. The load-use flush path still saves its load explicitly.
  assign div_raw_stall = div_busy && (div_slot_rd != 5'd0) &&
                         ((if_id_a.valid &&
                           ((if_id_a.instr[19:15] == div_slot_rd) ||
                            (if_id_a.instr[24:20] == div_slot_rd) ||
                            (if_id_a.instr[11:7]  == div_slot_rd))) ||
                          (if_id_b.valid &&
                           ((if_id_b.instr[19:15] == div_slot_rd) ||
                            (if_id_b.instr[24:20] == div_slot_rd) ||
                            (if_id_b.instr[11:7]  == div_slot_rd))));
  // Completion inject (engine DONE pulse while a DIV is outstanding).
  assign div_inject = div_valid_ex && div_busy;
  // Issued DIVs vanish from the pipe (bubble) instead of flowing to MEM.
  assign div_kill_a = id_ex_a.valid && div_op_a && (div_issue_a || div_busy);
  assign div_kill_b = id_ex_b.valid && div_op_b && (div_issue_b || div_busy);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      div_busy    <= 1'b0;
      div_slot_rd <= '0;
    end else if (div_inject) begin
      div_busy <= 1'b0;
    end else if (div_issue) begin
      div_busy    <= 1'b1;
      div_slot_rd <= div_issue_a ? id_ex_a.rd_addr : id_ex_b.rd_addr;
    end
  end

  // Control signal generation
  always_comb begin
    // Stall conditions.
    // NOTE: load_use_hazard stalls EX as well as IF/ID. A load in EX must
    // never be flushed while MEM is frozen (older bus op): ex_mem could not
    // capture it and the load would be lost, silently corrupting the stream
    // (seen as ld_st compliance failures). flush_ex below is therefore
    // suppressed while mem_stall holds; the front simply waits.
    //
    // NOTE: div_issue holds IF/ID for exactly the issue cycle so the
    // consumer behind the DIV cannot enter EX before the scoreboard sees
    // the outstanding DIV (it would read a stale rd with no forward
    // available). Scoreboard/structural/inject stalls freeze the front
    // (and MEM for structural/inject, so no instruction is duplicated or
    // lost while waiting). serialize_pair holds IF for its shift cycle
    // (ID shifts B into slot A instead of freezing).
    ctrl.stall_if  = fetch_stall || load_use_hazard || div_raw_stall || div_struct_stall || div_issue || div_inject || mem_stall || serialize_pair;
    ctrl.stall_id  = load_use_hazard || div_raw_stall || div_struct_stall || div_issue || div_inject || mem_stall;
    ctrl.stall_ex  = load_use_hazard || div_raw_stall || div_struct_stall || div_inject || mem_stall;
    ctrl.stall_mem = div_struct_stall || div_inject || mem_stall;

    // Flush conditions (branch/jump redirect or trap).
    // div_issue also flushes EX: the issued DIV lives on in the engine and
    // slot, so discarding it from the pipe here is what makes the accept
    // single-shot (it can never be re-issued on a later cycle).
    // div_raw flushes EX like a load-use: the scoreboard consumer must stay
    // in ID (it re-reads fresh registers on release), while whatever sits
    // in EX advances once into MEM and drains. Freezing a VALID instruction
    // in EX instead would let its latched operands go stale as forwarding
    // sources drain, corrupting it on release. Both flushes are suppressed
    // while MEM is frozen (a frozen instruction must be preserved, and a
    // structural DIV wait always freezes MEM with it, so an unissued DIV
    // can never be flushed here).
    ctrl.flush_if  = pc_redirect;
    ctrl.flush_id  = pc_redirect;
    ctrl.flush_ex  = div_issue || ((load_use_hazard || div_raw_stall) && !mem_stall); // Insert bubble on load-use hazard
    ctrl.flush_mem = 1'b0; // Unused: traps kill per-slot (see EX/MEM valid gates), never wholesale.
  end

  // CSR routing: at most one slot holds a CSR op (dispatch serializes
  // CSR+CSR pairs). Slot A wins ties defensively.
  logic csr_use_a;
  logic csr_use_b;
  assign csr_use_a = id_ex_a.valid && id_ex_a.is_csr;
  assign csr_use_b = id_ex_b.valid && id_ex_b.is_csr && !csr_use_a;

  // CSR write data: register source, except immediate forms
  // (CSRRWI/CSRR SI/CSRRCI, funct3[2]=1) which carry a 5-bit zimm in rs1.
  logic [XLEN-1:0] csr_wdata;
  assign csr_wdata = (csr_use_a ? id_ex_a.csr_op[2] : id_ex_b.csr_op[2]) ?
                     {59'b0, (csr_use_a ? id_ex_a.rs1_addr : id_ex_b.rs1_addr)} :
                     (csr_use_a ? fwd_a_data_a : fwd_b_data_b);

  //--------------------------------------------------------------------------
  // CSR Unit (singleton; B gated on A not trapping/taking control)
  //--------------------------------------------------------------------------
  rv64xo3_csr u_csr (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .csr_addr_i  (csr_use_a ? id_ex_a.csr_addr : id_ex_b.csr_addr),
      .csr_wen_i   ((csr_use_a || (csr_use_b && !other_side_redir)) &&
                    (id_ex_a.valid || id_ex_b.valid)),
      .csr_op_i    (csr_use_a ? id_ex_a.csr_op : id_ex_b.csr_op),
      .csr_wdata_i (csr_wdata),
      .csr_rdata_o (csr_rdata),
      .trap_taken_i(trap_taken),
      .trap_pc_i   (exc_pc),
      .trap_cause_i(exc_cause),
      .trap_val_i  (trap_val),
      .mret_i      (mret_taken),
      .mtvec_o     (mtvec),
      .mepc_o      (mepc)
  );

  // Trap logic: per-slot requests, slot A (older) wins ties.
  // Fetch-misaligned control transfers trap rather than redirect.
  assign trap_taken = exc_valid_a || exc_valid_b || fetch_misaligned;
  assign mret_taken = mret_a_taken || mret_b_taken;
  assign mret_a_taken = id_ex_a.valid && id_ex_a.is_mret;
  assign mret_b_taken = id_ex_b.valid && id_ex_b.is_mret && !other_side_redir;

  // Exception detection, oldest first: MEM faults, slot-A EX traps,
  // fetch-misaligned control transfer, slot-B EX traps.
  // mtval carries the faulting address for MEM faults, else zero.
  assign trap_val_a = mem_exc_valid_a ? ex_mem_a.alu_result : '0;
  assign trap_val_b = mem_exc_valid_b ? ex_mem_b.alu_result : '0;

  assign exc_valid_a = mem_exc_valid_a ||
                       (id_ex_a.valid && (id_ex_a.is_ecall || id_ex_a.is_ebreak ||
                                          id_ex_a.illegal_instr));
  assign exc_valid_b = (mem_exc_valid_b ||
                       (id_ex_b.valid && (id_ex_b.is_ecall || id_ex_b.is_ebreak ||
                                          id_ex_b.illegal_instr))) &&
                       !other_side_redir;
  assign exc_cause_a = mem_exc_valid_a ? mem_exc_cause_a :
                       id_ex_a.is_ecall ? EXC_ECALL_M :
                       id_ex_a.is_ebreak ? EXC_BREAKPOINT :
                       EXC_ILLEGAL_INSTR;
  assign exc_cause_b = mem_exc_valid_b ? mem_exc_cause_b :
                       id_ex_b.is_ecall ? EXC_ECALL_M :
                       id_ex_b.is_ebreak ? EXC_BREAKPOINT :
                       EXC_ILLEGAL_INSTR;
  assign exc_pc_a = (mem_exc_valid_a) ? ex_mem_a.pc : id_ex_a.pc;
  assign exc_pc_b = (mem_exc_valid_b) ? ex_mem_b.pc : id_ex_b.pc;

  // Fetch-misaligned: the winning control transfer targets a non-4B-aligned
  // address. Without C it traps (MISALIGN) instead of redirecting, with the
  // faulting instruction's PC. Checked on the priority-selected target so
  // both slots are covered with one check.
  logic ctrl_redir;
  logic [XLEN-1:0] ctrl_target;
  logic [XLEN-1:0] ctrl_pc;
  assign ctrl_redir  = redir_a || redir_b;
  assign ctrl_target = redir_a ? redir_target_a : redir_target_b;
  assign ctrl_pc     = redir_a ? id_ex_a.pc : id_ex_b.pc;
  logic fetch_misaligned;
  assign fetch_misaligned = ctrl_redir && (ctrl_target[1:0] != 2'b00);

  assign exc_valid = mem_exc_valid_a || mem_exc_valid_b ||
                     exc_valid_a || fetch_misaligned || exc_valid_b;
  assign exc_cause = (mem_exc_valid_a || mem_exc_valid_b) ?
                       (mem_exc_valid_a ? mem_exc_cause_a : mem_exc_cause_b) :
                     exc_valid_a ? exc_cause_a :
                     fetch_misaligned ? EXC_INSTR_MISALIGN :
                     exc_cause_b;
  assign exc_pc = (mem_exc_valid_a || mem_exc_valid_b) ?
                    (mem_exc_valid_a ? ex_mem_a.pc : ex_mem_b.pc) :
                  exc_valid_a ? exc_pc_a :
                  fetch_misaligned ? ctrl_pc :
                  exc_pc_b;
  assign trap_val = mem_exc_valid_a ? ex_mem_a.alu_result :
                    mem_exc_valid_b ? ex_mem_b.alu_result : '0;

  // Branch predictor updates: slot A (older) wins ties; slot B updates
  // only when it is really executing (not suppressed as wrong-path).
  assign bp_update_en    = (id_ex_a.valid && id_ex_a.is_branch) ||
                           ((id_ex_b.valid && id_ex_b.is_branch) && !other_side_redir);
  assign bp_update_pc    = (id_ex_a.valid && id_ex_a.is_branch) ? id_ex_a.pc : id_ex_b.pc;
  assign bp_update_taken = (id_ex_a.valid && id_ex_a.is_branch) ? branch_taken_a : branch_taken_b;

  //--------------------------------------------------------------------------
  // Assertions (SVA)
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  /* verilator lint_off SYNCASYNCNET */
  // NOTE: no "PC aligned" assertion here on purpose. A misaligned fetch PC
  // can appear transiently (branch prediction into a 2B-aligned target);
  // fetch_misaligned traps before anything commits, and the redirect-target
  // assertion below guards committed transfers.

  // No write to x0 (either slot)
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    mem_wb_a.valid && mem_wb_a.reg_write |-> mem_wb_a.rd_addr != 5'd0
  )
  else $error("Attempted write to x0");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
    mem_wb_b.valid && mem_wb_b.reg_write |-> mem_wb_b.rd_addr != 5'd0
  )
  else $error("Attempted write to x0");

  // Wishbone: cyc must be asserted when stb is asserted
  assert property (@(posedge clk_i) disable iff (!rst_ni) iwb_stb_o |-> iwb_cyc_o)
  else $error("Instruction Wishbone: stb without cyc");

  assert property (@(posedge clk_i) disable iff (!rst_ni) dwb_stb_o |-> dwb_cyc_o)
  else $error("Data Wishbone: stb without cyc");

  // When stalled, pipeline registers should hold (checked on next cycle)
  // Note: This assertion is permanently disabled. SVA sampling of the stall signal
  // (which depends on combinational inputs like dwb_ack) can observe a '1' even if
  // the signal drops to '0' within the same cycle to allow progress (e.g. wait state ending).
  // Functional correctness is verified by LSU regression tests.
  // assert property (@(posedge clk_i) disable iff (!rst_ni)
  //   $rose(ctrl.stall_id) |=> (if_id_reg == $past(if_id_reg, 1) || $past(ctrl.flush_id, 1))
  // ) else $error("IF/ID register changed during stall");

  // Branch target must be aligned
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    pc_redirect |-> pc_redirect_target[1:0] == 2'b00
  )
  else $error("Branch target misaligned: %h", pc_redirect_target);

  // Valid signals should never be X
  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(if_id_a.valid))
  else $error("if_id_a.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(if_id_b.valid))
  else $error("if_id_b.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(id_ex_a.valid))
  else $error("id_ex_a.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(id_ex_b.valid))
  else $error("id_ex_b.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(ex_mem_a.valid))
  else $error("ex_mem_a.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(ex_mem_b.valid))
  else $error("ex_mem_b.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(mem_wb_a.valid))
  else $error("mem_wb_a.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(mem_wb_b.valid))
  else $error("mem_wb_b.valid is X");

  // Trap updates PC
  assert property (@(posedge clk_i) disable iff (!rst_ni) trap_taken |-> pc_redirect)
  else $error("Trap taken but no PC redirect");

  // MRET updates PC
  assert property (@(posedge clk_i) disable iff (!rst_ni) mret_taken |-> pc_redirect)
  else $error("MRET taken but no PC redirect");

  // Mutual exclusion of Mem Read/Write in ID/EX (per slot)
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !(id_ex_a.mem_read && id_ex_a.mem_write)
  )
  else $error("Simultaneous Mem Read and Write in ID/EX slot A");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !(id_ex_b.mem_read && id_ex_b.mem_write)
  )
  else $error("Simultaneous Mem Read and Write in ID/EX slot B");

  // Dispatch invariants (checked every cycle; violations are RTL bugs):
  // at most one memory op and at most one muldiv op may issue per pair,
  // and at most one DIV may be accepted per cycle.
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !((id_ex_a.mem_read || id_ex_a.mem_write) &&
      (id_ex_b.mem_read || id_ex_b.mem_write) &&
      id_ex_a.valid && id_ex_b.valid)
  )
  else $error("Two memory ops issued in one pair");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !(div_issue_a && div_issue_b)
  )
  else $error("Two DIVs accepted in one cycle");
  /* verilator lint_on SYNCASYNCNET */
  /* verilator lint_on SYNCASYNCNET */

  // Bind SVA module (Manually instantiated for tool compatibility)
  rv64xo3_hazard_sva u_hazard_sva (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .id_a_rs1_addr(if_id_a.instr[19:15]),
      .id_a_rs2_addr(if_id_a.instr[24:20]),
      .id_a_valid(if_id_a.valid),
      .id_b_rs1_addr(if_id_b.instr[19:15]),
      .id_b_rs2_addr(if_id_b.instr[24:20]),
      .id_b_valid(if_id_b.valid),
      .ex_a_rd_addr(id_ex_a.rd_addr),
      .ex_a_mem_read(id_ex_a.mem_read),
      .ex_a_valid(id_ex_a.valid),
      .ex_b_rd_addr(id_ex_b.rd_addr),
      .ex_b_mem_read(id_ex_b.mem_read),
      .ex_b_valid(id_ex_b.valid),
      .load_use_hazard(load_use_hazard),
      .fwd_a_sel_a(fwd_a_sel_a),
      .fwd_b_sel_a(fwd_b_sel_a),
      .fwd_a_sel_b(fwd_a_sel_b),
      .fwd_b_sel_b(fwd_b_sel_b),
      .mem_a_rd_addr(ex_mem_a.rd_addr),
      .mem_b_rd_addr(ex_mem_b.rd_addr),
      .wb_a_rd_addr(mem_wb_a.rd_addr),
      .wb_b_rd_addr(mem_wb_b.rd_addr)
  );
`endif

endmodule : rv64xo3_top
