// IronCore IF Stage - Instruction Fetch
// Handles PC management and instruction memory interface

import ironcore_pkg::*;
module ironcore_if #(
    parameter logic [ironcore_pkg::XLEN-1:0] RESET_PC = 64'h8000_0000
) (
    input logic clk_i,
    input logic rst_ni,

    // Control inputs
    input logic            stall_i,
    input logic            flush_i,
    input logic            pc_redirect_i,
    input logic [XLEN-1:0] pc_target_i,

    // Branch prediction inputs
    input logic            pred_taken_i,
    input logic [XLEN-1:0] pred_target_i,

    // Wishbone instruction interface
    output logic            iwb_cyc_o,
    output logic            iwb_stb_o,
    output logic [XLEN-1:0] iwb_adr_o,
    input  logic [XLEN-1:0] iwb_dat_i,
    input  logic            iwb_ack_i,

    // Stage outputs
    output logic [XLEN-1:0] pc_o,
    output logic [ILEN-1:0] instr_o,
    output logic            instr_valid_o,
    output logic            fetch_stall_o
);

  //--------------------------------------------------------------------------
  // PC Register
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] pc_reg;
  logic [XLEN-1:0] pc_next;

  // FSM for fetch
  typedef enum logic [1:0] {
    IDLE,
    FETCH,
    WAIT_ACK
  } fetch_state_e;

  fetch_state_e state, state_next;

  // Instruction buffer (for holding fetched instruction during stalls)
  logic [ILEN-1:0] instr_buf;
  logic            instr_buf_valid;

  //--------------------------------------------------------------------------
  // PC Next Logic
  //--------------------------------------------------------------------------
  always_comb begin
    if (pc_redirect_i) begin
      pc_next = pc_target_i;
    end else if (pred_taken_i && !stall_i) begin
      pc_next = pred_target_i;
    end else if (!stall_i && instr_valid_o) begin
      pc_next = pc_reg + 32'd4;
    end else begin
      pc_next = pc_reg;
    end
  end

  //--------------------------------------------------------------------------
  // PC Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_reg <= RESET_PC;
    end else begin
      pc_reg <= pc_next;
    end
  end

  //--------------------------------------------------------------------------
  // Fetch State Machine
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
    end else begin
      state <= state_next;
    end
  end

  always_comb begin
    state_next = state;

    case (state)
      IDLE: begin
        if (!stall_i && !pc_redirect_i) begin
          state_next = FETCH;
        end
      end

      FETCH: begin
        if (pc_redirect_i) begin
          state_next = IDLE;
        end else begin
          state_next = WAIT_ACK;
        end
      end

      WAIT_ACK: begin
        if (pc_redirect_i) begin
          state_next = IDLE;
        end else if (iwb_ack_i) begin
          if (stall_i) begin
            state_next = IDLE;
          end else begin
            state_next = FETCH;
          end
        end
      end

      default: state_next = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // Wishbone Interface
  //--------------------------------------------------------------------------
  assign iwb_cyc_o = (state == FETCH) || (state == WAIT_ACK);
  assign iwb_stb_o = (state == FETCH) || (state == WAIT_ACK && !iwb_ack_i);
  assign iwb_adr_o = pc_reg;

  //--------------------------------------------------------------------------
  // Instruction Buffer
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_buf       <= '0;
      instr_buf_valid <= 1'b0;
    end else if (pc_redirect_i || flush_i) begin
      instr_buf_valid <= 1'b0;
    end else if (iwb_ack_i && stall_i) begin
      // Buffer instruction if downstream is stalled
      instr_buf       <= iwb_dat_i;
      instr_buf_valid <= 1'b1;
    end else if (!stall_i && instr_buf_valid) begin
      // Clear buffer when consumed
      instr_buf_valid <= 1'b0;
    end
  end

  //--------------------------------------------------------------------------
  // Output Logic
  //--------------------------------------------------------------------------
  assign pc_o = pc_reg;

  always_comb begin
    if (instr_buf_valid) begin
      instr_o       = instr_buf;
      instr_valid_o = 1'b1;
    end else if (iwb_ack_i) begin
      instr_o       = iwb_dat_i;
      instr_valid_o = 1'b1;
    end else begin
      instr_o       = '0;
      instr_valid_o = 1'b0;
    end
  end

  // Stall upstream if waiting for memory
  assign fetch_stall_o = (state == WAIT_ACK) && !iwb_ack_i;

endmodule : ironcore_if
