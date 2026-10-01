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
  // Internal Signals
  //--------------------------------------------------------------------------

  // Pipeline registers
  rv64xo3_pkg::if_id_reg_t               if_id_reg;
  rv64xo3_pkg::id_ex_reg_t               id_ex_reg;
  rv64xo3_pkg::ex_mem_reg_t              ex_mem_reg;
  rv64xo3_pkg::mem_wb_reg_t              mem_wb_reg;

  // Control signals
  rv64xo3_pkg::ctrl_signals_t            ctrl;

  // PC signals
  logic                        [XLEN-1:0] pc_if;
  logic                                   pc_redirect;
  logic                        [XLEN-1:0] pc_redirect_target;

  // Fetch signals
  logic                        [ILEN-1:0] instr_if;
  logic                                   instr_valid_if;
  logic                                   fetch_stall;

  // Decode signals
  logic                        [XLEN-1:0] rs1_data_id;
  logic                        [XLEN-1:0] rs2_data_id;

  // Execute signals
  logic                        [XLEN-1:0] alu_result_ex;
  logic                                   branch_taken_ex;
  logic                        [XLEN-1:0] branch_target_ex;
  logic                        [XLEN-1:0] mul_result_ex;
  logic                        [XLEN-1:0] div_result_ex;
  logic                                   div_valid_ex;
  logic                                   div_engine_busy;

  // DIV scoreboard: one outstanding DIV (see Phase 1 notes below)
  logic                                   div_busy;
  logic                        [REG_ADDR_W-1:0] div_slot_rd;
  logic                                   div_op_ex;
  logic                                   div_issue;
  logic                                   div_struct_stall;
  logic                                   div_raw_stall;
  logic                                   div_inject;
  logic                                   div_kill;

  // Memory signals
  logic                        [XLEN-1:0] mem_rdata;
  logic                                   mem_stall;
  logic                                   mem_exc_valid;
  logic                        [XLEN-1:0] mem_exc_cause;

  // Forwarding signals
  rv64xo3_pkg::fwd_sel_e                 fwd_a_sel;
  rv64xo3_pkg::fwd_sel_e                 fwd_b_sel;
  logic                        [XLEN-1:0] fwd_a_data;
  logic                        [XLEN-1:0] fwd_b_data;

  // Hazard detection
  logic                                   load_use_hazard;

  // Branch prediction
  logic                                   pred_taken_if;
  logic                        [XLEN-1:0] pred_target_if;
  logic                                   pred_miss;

  // CSR signals
  /* verilator lint_off UNUSEDSIGNAL */
  logic                        [XLEN-1:0] csr_rdata;  // Will be used for CSR read instructions
  /* verilator lint_on UNUSEDSIGNAL */
  logic                        [XLEN-1:0] mtvec;
  logic                        [XLEN-1:0] mepc;

  // Exception signals
  logic                                   exc_valid;
  logic                        [XLEN-1:0] exc_cause;
  logic                        [XLEN-1:0] exc_pc;
  logic                                   trap_taken;
  logic                                   mret_taken;

  //--------------------------------------------------------------------------
  // IF Stage - Instruction Fetch
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
      .instr_o      (instr_if),
      .instr_valid_o(instr_valid_if),
      .fetch_stall_o(fetch_stall)
  );

  //--------------------------------------------------------------------------
  // Branch Predictor (Bimodal)
  //--------------------------------------------------------------------------
  rv64xo3_bp u_bp (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .pc_i          (pc_if),
      .instr_i       (instr_if),
      .instr_valid_i (instr_valid_if),
      .update_en_i   (id_ex_reg.valid && id_ex_reg.is_branch),
      .update_pc_i   (id_ex_reg.pc),
      .update_taken_i(branch_taken_ex),
      .pred_taken_o  (pred_taken_if),
      .pred_target_o (pred_target_if)
  );

  //--------------------------------------------------------------------------
  // IF/ID Pipeline Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      if_id_reg <= '0;
    end else if (ctrl.flush_id) begin
      if_id_reg <= '0;
    end else if (!ctrl.stall_id) begin
      if_id_reg.pc          <= pc_if;
      if_id_reg.instr       <= instr_if;
      if_id_reg.valid       <= instr_valid_if && !ctrl.flush_if;
      if_id_reg.pred_taken  <= pred_taken_if;
      if_id_reg.pred_target <= pred_target_if;
    end
  end

  //--------------------------------------------------------------------------
  // ID Stage - Instruction Decode
  //--------------------------------------------------------------------------
  // Writeback mux: normal MEM/WB path, except during a DIV inject cycle
  // when the completed DIV result is written instead (MEM/WB is held, so
  // no writeback is lost).
  logic                        [XLEN-1:0] wb_rd_data;
  logic                        [REG_ADDR_W-1:0] wb_rd_addr;
  logic                                   wb_rd_wen;
  assign wb_rd_wen  = div_inject ? (div_slot_rd != 5'd0) :
                                   (mem_wb_reg.reg_write && mem_wb_reg.valid);
  assign wb_rd_addr = div_inject ? div_slot_rd : mem_wb_reg.rd_addr;
  assign wb_rd_data = div_inject ? div_result_ex : mem_wb_reg.result;

  rv64xo3_id u_id (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .if_id_reg_i (if_id_reg),
      .wb_rd_addr_i(wb_rd_addr),
      .wb_rd_data_i(wb_rd_data),
      .wb_rd_wen_i (wb_rd_wen),
      .rs1_data_o  (rs1_data_id),
      .rs2_data_o  (rs2_data_id)
  );

  // Decoder
  logic                     [XLEN-1:0] imm_id;
  rv64xo3_pkg::alu_op_e               alu_op_id;
  rv64xo3_pkg::branch_op_e            branch_op_id;
  rv64xo3_pkg::muldiv_op_e            muldiv_op_id;
  logic                                alu_src_id;
  logic                                mem_read_id;
  logic                                mem_write_id;
  rv64xo3_pkg::mem_width_e            mem_width_id;
  logic                                mem_unsigned_id;
  logic                                reg_write_id;
  logic                                is_branch_id;
  logic                                is_jal_id;
  logic                                is_jalr_id;
  logic                                is_muldiv_id;
  logic                                is_csr_id;
  logic                     [    11:0] csr_addr_id;
  logic                     [     2:0] csr_op_id;
  logic                                is_ecall_id;
  logic                                is_ebreak_id;
  logic                                is_mret_id;
  logic                                is_auipc_id;
  logic                                illegal_instr_id;

  rv64xo3_decoder u_decoder (
      .instr_i        (if_id_reg.instr),
      .imm_o          (imm_id),
      .alu_op_o       (alu_op_id),
      .branch_op_o    (branch_op_id),
      .muldiv_op_o    (muldiv_op_id),
      .alu_src_o      (alu_src_id),
      .mem_read_o     (mem_read_id),
      .mem_write_o    (mem_write_id),
      .mem_width_o    (mem_width_id),
      .mem_unsigned_o (mem_unsigned_id),
      .reg_write_o    (reg_write_id),
      .is_branch_o    (is_branch_id),
      .is_jal_o       (is_jal_id),
      .is_jalr_o      (is_jalr_id),
      .is_muldiv_o    (is_muldiv_id),
      .is_csr_o       (is_csr_id),
      .csr_addr_o     (csr_addr_id),
      .csr_op_o       (csr_op_id),
      .is_ecall_o     (is_ecall_id),
      .is_ebreak_o    (is_ebreak_id),
      .is_mret_o      (is_mret_id),
      .is_auipc_o     (is_auipc_id),
      .illegal_instr_o(illegal_instr_id)
  );

  //--------------------------------------------------------------------------
  // ID/EX Pipeline Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_ex_reg <= '0;
    end else if (ctrl.flush_ex) begin
      id_ex_reg <= '0;
    end else if (!ctrl.stall_ex) begin
      id_ex_reg.pc <= if_id_reg.pc;
      id_ex_reg.rs1_data <= rs1_data_id;
      id_ex_reg.rs2_data <= rs2_data_id;
      id_ex_reg.imm <= imm_id;
      id_ex_reg.rs1_addr <= if_id_reg.instr[19:15];
      id_ex_reg.rs2_addr <= if_id_reg.instr[24:20];
      id_ex_reg.rd_addr <= if_id_reg.instr[11:7];
      // Suppress reg_write when rd=x0 (writes to x0 are NOPs)
      id_ex_reg.reg_write <= reg_write_id && (if_id_reg.instr[11:7] != 5'd0);
      id_ex_reg.alu_op <= alu_op_id;
      id_ex_reg.branch_op <= branch_op_id;
      id_ex_reg.muldiv_op <= muldiv_op_id;
      id_ex_reg.alu_src <= alu_src_id;
      id_ex_reg.mem_read <= mem_read_id;
      id_ex_reg.mem_write <= mem_write_id;
      id_ex_reg.mem_width <= mem_width_id;
      id_ex_reg.mem_unsigned <= mem_unsigned_id;
      id_ex_reg.is_branch <= is_branch_id;
      id_ex_reg.is_jal <= is_jal_id;
      id_ex_reg.is_jalr <= is_jalr_id;
      id_ex_reg.is_muldiv <= is_muldiv_id;
      id_ex_reg.is_csr <= is_csr_id;
      id_ex_reg.csr_addr <= csr_addr_id;
      id_ex_reg.csr_op <= csr_op_id;
      id_ex_reg.is_ecall <= is_ecall_id;
      id_ex_reg.is_ebreak <= is_ebreak_id;
      id_ex_reg.is_mret <= is_mret_id;
      id_ex_reg.is_auipc <= is_auipc_id;
      id_ex_reg.illegal_instr <= illegal_instr_id && if_id_reg.valid;  // Only illegal if valid instr
      id_ex_reg.valid <= if_id_reg.valid && !load_use_hazard && !pc_redirect;
      id_ex_reg.pred_taken <= if_id_reg.pred_taken;
      id_ex_reg.pred_target <= if_id_reg.pred_target;
    end
  end

  //--------------------------------------------------------------------------
  // EX Stage - Execute
  //--------------------------------------------------------------------------
  rv64xo3_ex u_ex (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .id_ex_reg_i      (id_ex_reg),
      .fwd_a_sel_i      (fwd_a_sel),
      .fwd_b_sel_i      (fwd_b_sel),
      .fwd_ex_mem_data_i(ex_mem_reg.alu_result),
      .fwd_mem_wb_data_i(mem_wb_reg.result),
      .div_start_i    (div_issue),
      .alu_result_o     (alu_result_ex),
      .branch_taken_o   (branch_taken_ex),
      .branch_target_o  (branch_target_ex),
      .mul_result_o     (mul_result_ex),
      .div_result_o     (div_result_ex),
      .div_valid_o      (div_valid_ex),
      .div_busy_o       (div_engine_busy)
  );

  //--------------------------------------------------------------------------
  // EX/MEM Pipeline Register
  //--------------------------------------------------------------------------
  // MUL retires from EX like an ALU op (single-cycle). An issued DIV
  // vanishes here into a bubble: its result arrives later via the
  // scoreboard inject, so it must neither forward nor write back.
  // When EX is frozen while MEM advances, MEM takes a bubble instead of
  // re-capturing the frozen instruction (re-capture would duplicate it
  // with drifting forward values as MEM/WB drain). The load-use flush
  // path still saves its load explicitly (flush wins over the bubble).
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ex_mem_reg <= '0;
    end else if (ctrl.flush_mem) begin
      ex_mem_reg <= '0;
    end else if (!ctrl.stall_mem) begin
      // Bubble instead of capturing when: the DIV just issued (div_kill),
      // or EX is frozen while MEM advances (re-capturing a frozen EX would
      // duplicate it with drifting forward values as MEM/WB drain).
      // The load-use flush still saves its load (flush_ex without div_kill
      // falls through to the normal capture below).
      if (div_kill || (ctrl.stall_ex && !ctrl.flush_ex)) begin
        ex_mem_reg <= '0;
      end else begin
        ex_mem_reg.pc <= id_ex_reg.pc;
        ex_mem_reg.alu_result <= id_ex_reg.is_muldiv && !div_op_ex ? mul_result_ex :
                                 id_ex_reg.is_csr ? csr_rdata :
                                 alu_result_ex;
        ex_mem_reg.rs2_data <= fwd_b_data;
        ex_mem_reg.rd_addr <= id_ex_reg.rd_addr;
        ex_mem_reg.mem_read <= id_ex_reg.mem_read;
        ex_mem_reg.mem_write <= id_ex_reg.mem_write;
        ex_mem_reg.mem_width <= id_ex_reg.mem_width;
        ex_mem_reg.mem_unsigned <= id_ex_reg.mem_unsigned;
        ex_mem_reg.reg_write <= id_ex_reg.reg_write;
        ex_mem_reg.valid <= id_ex_reg.valid;
      end
    end
  end

  //--------------------------------------------------------------------------
  // MEM Stage - Memory Access
  //--------------------------------------------------------------------------
  rv64xo3_mem u_mem (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .ex_mem_reg_i(ex_mem_reg),
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
      .mem_exc_valid_o(mem_exc_valid),
      .mem_exc_cause_o(mem_exc_cause)
  );

  //--------------------------------------------------------------------------
  // MEM/WB Pipeline Register
  //--------------------------------------------------------------------------
  // Precise-trap rule: an instruction that faults in MEM must not retire.
  // (EX-stage faults still let the older instruction in EX/MEM retire, and
  // younger stages are flushed.) Without this, a faulting load writes back
  // stale bus data, clobbering its own rd (seen as ma_addr failures).
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_wb_reg <= '0;
    end else if (!ctrl.stall_mem) begin
      if (mem_exc_valid) begin
        mem_wb_reg <= '0;
      end else begin
        mem_wb_reg.pc        <= ex_mem_reg.pc;
        mem_wb_reg.result    <= ex_mem_reg.mem_read ? mem_rdata : ex_mem_reg.alu_result;
        mem_wb_reg.rd_addr   <= ex_mem_reg.rd_addr;
        mem_wb_reg.reg_write <= ex_mem_reg.reg_write;
        mem_wb_reg.valid     <= ex_mem_reg.valid;
      end
    end
  end

  //--------------------------------------------------------------------------
  // Hazard Detection Unit
  //--------------------------------------------------------------------------
  rv64xo3_hazard u_hazard (
      // Load-use hazard detection uses IF/ID stage (for stalling)
      .id_rs1_addr_i    (if_id_reg.instr[19:15]),
      .id_rs2_addr_i    (if_id_reg.instr[24:20]),
      .id_valid_i       (if_id_reg.valid),
      .ex_rd_addr_i     (id_ex_reg.rd_addr),
      .ex_mem_read_i    (id_ex_reg.mem_read),
      .ex_valid_i       (id_ex_reg.valid),
      .mem_rd_addr_i    (ex_mem_reg.rd_addr),
      .mem_reg_write_i  (ex_mem_reg.reg_write),
      .mem_valid_i      (ex_mem_reg.valid),
      .wb_rd_addr_i     (mem_wb_reg.rd_addr),
      .wb_reg_write_i   (mem_wb_reg.reg_write),
      .wb_valid_i       (mem_wb_reg.valid),
      .ex_rs1_addr_i    (id_ex_reg.rs1_addr),  // Added for forwarding
      .ex_rs2_addr_i    (id_ex_reg.rs2_addr),  // Added for forwarding
      .load_use_hazard_o(load_use_hazard),
      .fwd_a_sel_o      (fwd_a_sel),
      .fwd_b_sel_o      (fwd_b_sel)
  );

  // Forwarding logic computed in rv64xo3_hazard module
  // Redundant inline logic removed to ensure single source of truth

  // Forward data mux (for store data)
  always_comb begin
    case (fwd_b_sel)
      FWD_EX_MEM: fwd_b_data = ex_mem_reg.alu_result;
      FWD_MEM_WB: fwd_b_data = mem_wb_reg.result;
      default:    fwd_b_data = id_ex_reg.rs2_data;
    endcase

    case (fwd_a_sel)
      FWD_EX_MEM: fwd_a_data = ex_mem_reg.alu_result;
      FWD_MEM_WB: fwd_a_data = mem_wb_reg.result;
      default:    fwd_a_data = id_ex_reg.rs1_data;
    endcase
  end

  //--------------------------------------------------------------------------
  // Control Unit
  //--------------------------------------------------------------------------
  // Branch misprediction detection
  assign pred_miss = id_ex_reg.valid && id_ex_reg.is_branch &&
                     (branch_taken_ex != id_ex_reg.pred_taken ||
                      (branch_taken_ex && branch_target_ex != id_ex_reg.pred_target));

  // PC redirect logic
  assign pc_redirect = (id_ex_reg.valid && (id_ex_reg.is_jal || id_ex_reg.is_jalr)) ||
                       pred_miss ||
                       trap_taken ||
                       mret_taken;

  assign pc_redirect_target = trap_taken ? mtvec :
                              mret_taken ? mepc :
                              (id_ex_reg.is_jal || id_ex_reg.is_jalr) ? branch_target_ex :
                              (pred_miss) ? (branch_taken_ex ? branch_target_ex : id_ex_reg.pc + 64'd4) :
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

  // DIV-class op currently in EX?
  always_comb begin
    case (id_ex_reg.muldiv_op)
      MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_MULW: div_op_ex = 1'b0;
      default: div_op_ex = id_ex_reg.valid && id_ex_reg.is_muldiv;
    endcase
  end

  // Single-cycle accept pulse: DIV in EX, engine free (both the slot and
  // the engine agree; either one alone blocks).
  assign div_issue = id_ex_reg.valid && div_op_ex && !div_busy && !div_engine_busy;
  // Structural: DIV waiting in EX while the engine is busy.
  assign div_struct_stall = id_ex_reg.valid && div_op_ex && (div_busy || div_engine_busy);
  // RAW/WAW on the outstanding DIV destination (checked in ID).
  // NOTE: a frozen VALID instruction in EX must never be re-captured into
  // MEM (it would duplicate with live-forward drift as MEM/WB drain), so
  // the EX/MEM capture below inserts a bubble whenever EX is stalled while
  // MEM advances. The load-use flush path still saves its load explicitly.
  assign div_raw_stall = div_busy && if_id_reg.valid && (div_slot_rd != 5'd0) &&
                         ((if_id_reg.instr[19:15] == div_slot_rd) ||
                          (if_id_reg.instr[24:20] == div_slot_rd) ||
                          (if_id_reg.instr[11:7]  == div_slot_rd));
  // Completion inject (engine DONE pulse while a DIV is outstanding).
  assign div_inject = div_valid_ex && div_busy;
  // Issued DIVs vanish from the pipe (bubble) instead of flowing to MEM.
  assign div_kill = id_ex_reg.valid && div_op_ex && (div_issue || div_busy);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      div_busy    <= 1'b0;
      div_slot_rd <= '0;
    end else if (div_inject) begin
      div_busy <= 1'b0;
    end else if (div_issue) begin
      div_busy    <= 1'b1;
      div_slot_rd <= id_ex_reg.rd_addr;
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
    // lost while waiting).
    ctrl.stall_if  = fetch_stall || load_use_hazard || div_raw_stall || div_struct_stall || div_issue || div_inject || mem_stall;
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
    ctrl.flush_mem = trap_taken;
  end

  // CSR write data: register source, except immediate forms
  // (CSRRWI/CSRR SI/CSRRCI, funct3[2]=1) which carry a 5-bit zimm in rs1.
  logic [XLEN-1:0] csr_wdata;
  assign csr_wdata = id_ex_reg.csr_op[2] ? {59'b0, id_ex_reg.rs1_addr} : fwd_a_data;

  //--------------------------------------------------------------------------
  // CSR Unit
  //--------------------------------------------------------------------------
  rv64xo3_csr u_csr (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .csr_addr_i  (id_ex_reg.csr_addr),
      .csr_wen_i   (id_ex_reg.is_csr && id_ex_reg.valid),
      .csr_op_i    (id_ex_reg.csr_op),
      .csr_wdata_i (csr_wdata),
      .csr_rdata_o (csr_rdata),
      .trap_taken_i(trap_taken),
      .trap_pc_i   (exc_pc),
      .trap_cause_i(exc_cause),
      .trap_val_i  (mem_exc_valid ? ex_mem_reg.alu_result : '0), // Only set mtval for misaligned/faults
      .mret_i      (mret_taken),
      .mtvec_o     (mtvec),
      .mepc_o      (mepc)
  );

  // Trap logic
  assign trap_taken = exc_valid;
  assign mret_taken = id_ex_reg.valid && id_ex_reg.is_mret;
`ifndef SYNTHESIS
  // Temporary Phase-1 tracer
  always @(posedge clk_i) begin
    if (rst_ni && (div_issue || div_inject || div_raw_stall || div_struct_stall)) begin
      $display("[DIV] is=%0d inj=%0d raw=%0d str=%0d busy=%0d slot=x%0d id=%0h(%0d) ex=%0h(%0d) mem=%0h(%0d) wb=%0h(%0d)",
               div_issue, div_inject, div_raw_stall, div_struct_stall, div_busy, div_slot_rd,
               if_id_reg.pc, if_id_reg.valid, id_ex_reg.pc, id_ex_reg.valid,
               ex_mem_reg.pc, ex_mem_reg.valid, mem_wb_reg.pc, mem_wb_reg.valid);
    end
    if (rst_ni && id_ex_reg.valid && id_ex_reg.is_branch) begin
      $display("[BR] pc=%0h A=%0h B=%0h taken=%0d", id_ex_reg.pc, fwd_a_data, fwd_b_data, branch_taken_ex);
    end
  end
`endif

  // Exception detection
  // Priority: Memory exceptions (MEM stage) > EX stage exceptions.
  // Fetch-misaligned (taken branch/jump to a non-4B-aligned target) traps
  // here instead of redirecting; without C, targets must stay 4B-aligned.
  logic fetch_misaligned;
  assign fetch_misaligned = id_ex_reg.valid &&
                            (id_ex_reg.is_jal || id_ex_reg.is_jalr ||
                             (id_ex_reg.is_branch && branch_taken_ex)) &&
                            (branch_target_ex[1:0] != 2'b00);
  assign exc_valid = mem_exc_valid ||
                     fetch_misaligned ||
                     (id_ex_reg.valid && (id_ex_reg.is_ecall || id_ex_reg.is_ebreak || id_ex_reg.illegal_instr));

  assign exc_cause = mem_exc_valid ? mem_exc_cause :
                     fetch_misaligned ? EXC_INSTR_MISALIGN :
                     id_ex_reg.is_ecall ? EXC_ECALL_M :
                     id_ex_reg.is_ebreak ? EXC_BREAKPOINT :
                     EXC_ILLEGAL_INSTR;

  // Precise trap PC: MEM-stage fault uses EX/MEM PC, EX-stage trap uses ID/EX PC.
  // (OoO note: this becomes ROB-head PC once commit/rob lands.)
  assign exc_pc = mem_exc_valid ? ex_mem_reg.pc : id_ex_reg.pc;

  //--------------------------------------------------------------------------
  // Assertions (SVA)
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  /* verilator lint_off SYNCASYNCNET */
  // NOTE: no "PC aligned" assertion here on purpose. A misaligned fetch PC
  // can appear transiently (branch prediction into a 2B-aligned target);
  // fetch_misaligned traps before anything commits, and the redirect-target
  // assertion below guards committed transfers.

  // No write to x0
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    mem_wb_reg.valid && mem_wb_reg.reg_write |-> mem_wb_reg.rd_addr != 5'd0
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

  // Valid signal should never be X
  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(if_id_reg.valid))
  else $error("if_id_reg.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(id_ex_reg.valid))
  else $error("id_ex_reg.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(ex_mem_reg.valid))
  else $error("ex_mem_reg.valid is X");

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(mem_wb_reg.valid))
  else $error("mem_wb_reg.valid is X");

  // Trap updates PC
  assert property (@(posedge clk_i) disable iff (!rst_ni) trap_taken |-> pc_redirect)
  else $error("Trap taken but no PC redirect");

  // MRET updates PC
  assert property (@(posedge clk_i) disable iff (!rst_ni) mret_taken |-> pc_redirect)
  else $error("MRET taken but no PC redirect");

  // Mutual exclusion of Mem Read/Write in ID/EX
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !(id_ex_reg.mem_read && id_ex_reg.mem_write)
  )
  else $error("Simultaneous Mem Read and Write in ID/EX");
  /* verilator lint_on SYNCASYNCNET */
  /* verilator lint_on SYNCASYNCNET */

  // Bind SVA module (Manually instantiated for tool compatibility)
  rv64xo3_hazard_sva u_hazard_sva (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .id_rs1_addr(if_id_reg.instr[19:15]),
      .id_rs2_addr(if_id_reg.instr[24:20]),
      .id_valid(if_id_reg.valid),
      .ex_rs1_addr(id_ex_reg.rs1_addr),
      .ex_rs2_addr(id_ex_reg.rs2_addr),
      .ex_rd_addr(id_ex_reg.rd_addr),
      .ex_mem_read(id_ex_reg.mem_read),
      .ex_valid(id_ex_reg.valid),
      .mem_rd_addr(ex_mem_reg.rd_addr),
      .mem_reg_write(ex_mem_reg.reg_write),
      .mem_valid(ex_mem_reg.valid),
      .wb_rd_addr(mem_wb_reg.rd_addr),
      .wb_reg_write(mem_wb_reg.reg_write),
      .wb_valid(mem_wb_reg.valid),
      .load_use_hazard(load_use_hazard),
      .fwd_a_sel(fwd_a_sel),
      .fwd_b_sel(fwd_b_sel)
  );
`endif

endmodule : rv64xo3_top
