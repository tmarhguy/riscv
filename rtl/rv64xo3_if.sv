// riscv64xO3 IF Stage - 2-wide Instruction Fetch
// Pipelined fetch loop: stb stays asserted in RUN and the request address
// updates the cycle after each ack, so back-to-back acks deliver one
// aligned 64-bit parcel (two instructions) per cycle. A pair straddling an
// 8B boundary (pc[2]==1 after a 4B-aligned redirect) takes two transactions.
// Redirects/predictions drain via a one-cycle IDLE gap so in-flight acks
// can never be mistaken for the new stream.

import rv64xo3_pkg::*;
module rv64xo3_if #(
    parameter logic [rv64xo3_pkg::XLEN-1:0] RESET_PC = 64'h8000_0000
) (
    input logic clk_i,
    input logic rst_ni,

    // Control inputs
    input logic            stall_i,
    input logic            flush_i,
    input logic            pc_redirect_i,
    input logic [XLEN-1:0] pc_target_i,

    // Branch prediction inputs (slot 0 only; slot 1 defaults not-taken)
    input logic            pred_taken_i,
    input logic [XLEN-1:0] pred_target_i,

    // Wishbone instruction interface (64-bit data: two instructions)
    output logic            iwb_cyc_o,
    output logic            iwb_stb_o,
    output logic [XLEN-1:0] iwb_adr_o,
    input  logic [XLEN-1:0] iwb_dat_i,
    input  logic            iwb_ack_i,

    // Stage outputs (one aligned pair)
    output logic [XLEN-1:0] pc_o,
    output logic [ILEN-1:0] instr0_o,
    output logic [ILEN-1:0] instr1_o,
    output logic            pair_valid_o,
    output logic            fetch_stall_o
);

  typedef enum logic [1:0] {
    IDLE,
    RUN
  } fetch_state_e;

  fetch_state_e state, state_next;

  // Oldest not-yet-consumed pair address.
  logic [XLEN-1:0] pc_reg;
  // Set once the first word of a straddling pair arrived; the second word
  // (at word_base + 8) is outstanding.
  logic            await_hi;
  // Latched slot-0 half of a straddling pair (high half of first word).
  logic [ILEN-1:0] lo_half;
  logic            lo_half_valid;

  // Pair buffer: holds a completed pair while downstream is stalled.
  logic [XLEN-1:0] pair_pc;
  logic [ILEN-1:0] pair_lo;
  logic [ILEN-1:0] pair_hi;
  logic            pair_buf_valid;

  // First word of the current pair; straddlers need the next word too.
  logic [XLEN-1:0] word_base;
  logic            need_two;
  assign word_base = {pc_reg[XLEN-1:3], 3'b000};
  assign need_two  = pc_reg[2];

  // This ack finishes a pair: an aligned single-word fetch, or the second
  // word of a straddler (first word already latched).
  logic completing;
  assign completing = (state == RUN) && iwb_ack_i && !pair_buf_valid &&
                      (!need_two || await_hi);

  // Prediction steers the stream when a pair is presented and the front
  // is accepting it. Same-cycle: BP is combinational on the outputs.
  logic steer;
  assign steer = pred_taken_i && !stall_i && !pc_redirect_i &&
                 (pair_buf_valid || completing);

  always_comb begin
    state_next = state;
    case (state)
      IDLE: begin
        // Leave unconditionally (nothing outstanding to lose); acks in
        // IDLE are ignored. Redirects hold us here via the sequential
        // priority below.
        if (!pc_redirect_i && !flush_i)
          state_next = RUN;
      end
      RUN: begin
        // Any redirect/flush, steer, or stall-completion parks in IDLE;
        // back-to-back acks otherwise stream without gaps.
        if (pc_redirect_i || flush_i)
          state_next = IDLE;
        else if (steer || (iwb_ack_i && !pair_buf_valid && stall_i))
          state_next = IDLE;
      end
      default: state_next = IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
    end else begin
      state <= state_next;
    end
  end

  // PC and assembly registers.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_reg         <= RESET_PC;
      await_hi       <= 1'b0;
      lo_half        <= '0;
      lo_half_valid  <= 1'b0;
      pair_pc        <= '0;
      pair_lo        <= '0;
      pair_hi        <= '0;
      pair_buf_valid <= 1'b0;
    end else if (pc_redirect_i || flush_i) begin
      pc_reg         <= pc_redirect_i ? pc_target_i : pc_reg;
      await_hi       <= 1'b0;
      lo_half_valid  <= 1'b0;
      pair_buf_valid <= 1'b0;
    end else if (state == RUN && iwb_ack_i && !pair_buf_valid) begin
      if (stall_i) begin
        // Front frozen: keep one completed pair, drop a dangling first
        // half (the pair refetches cleanly on resume).
        if (!need_two || await_hi) begin
          pair_pc <= pc_reg;
          if (!need_two) begin
            pair_lo <= iwb_dat_i[31:0];
            pair_hi <= iwb_dat_i[63:32];
          end else begin
            pair_lo <= lo_half;
            pair_hi <= iwb_dat_i[31:0];
          end
          pair_buf_valid <= 1'b1;
        end
        await_hi      <= 1'b0;
        lo_half_valid <= 1'b0;
      end else if (steer) begin
        // Predicted-taken slot-0 branch: jump, abandon in-flight.
        pc_reg         <= pred_target_i;
        await_hi       <= 1'b0;
        lo_half_valid  <= 1'b0;
        pair_buf_valid <= 1'b0;
      end else if (!need_two || await_hi) begin
        // Pair completes: advance; the request address follows next cycle.
        pc_reg         <= pc_reg + 64'd8;
        await_hi       <= 1'b0;
        lo_half_valid  <= 1'b0;
        pair_buf_valid <= 1'b0;
      end else begin
        // First word of a straddler: latch slot 0, ask for word two.
        lo_half        <= iwb_dat_i[63:32];
        lo_half_valid  <= 1'b1;
        await_hi       <= 1'b1;
      end
    end else if (pair_buf_valid && !stall_i) begin
      // Buffered pair consumed downstream: advance past it (or steer to
      // a predicted target for the branch it contains).
      pc_reg         <= steer ? pred_target_i : pc_reg + 64'd8;
      await_hi       <= 1'b0;
      lo_half_valid  <= 1'b0;
      pair_buf_valid <= 1'b0;
    end
  end

  //--------------------------------------------------------------------------
  // Wishbone Interface: request outstanding every RUN cycle.
  //--------------------------------------------------------------------------
  // Aligned pairs need the single word at pc; straddlers need LO at
  // word_base first, then HI at word_base + 8 (slot 1 = its low half).
  assign iwb_cyc_o = (state == RUN);
  assign iwb_stb_o = (state == RUN);
  assign iwb_adr_o = (!await_hi) ? word_base : word_base + 64'd8;

  //--------------------------------------------------------------------------
  // Output Logic
  //--------------------------------------------------------------------------
  assign pc_o = pair_buf_valid ? pair_pc : pc_reg;

  always_comb begin
    if (pair_buf_valid) begin
      instr0_o     = pair_lo;
      instr1_o     = pair_hi;
      pair_valid_o = 1'b1;
    end else if (completing && !stall_i) begin
      // Pair completing on the bus now (steer still forwards it to ID;
      // pc_redirect_i above forces ID to drop it via flush).
      if (!need_two) begin
        instr0_o = iwb_dat_i[31:0];
        instr1_o = iwb_dat_i[63:32];
      end else begin
        instr0_o = lo_half;
        instr1_o = iwb_dat_i[31:0];
      end
      pair_valid_o = 1'b1;
    end else begin
      instr0_o     = '0;
      instr1_o     = '0;
      pair_valid_o = 1'b0;
    end
  end

  // The front never starves the pipe over request latency: gaps surface
  // as bubbles (pair_valid_o low), not stalls. Only a parked fetch with
  // nothing to show holds IF (serialize's shift cycle expects this).
  assign fetch_stall_o = (state == IDLE) && !pair_buf_valid;

endmodule : rv64xo3_if
