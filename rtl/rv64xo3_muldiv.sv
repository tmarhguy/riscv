// riscv64xO3 MulDiv Unit - Multiply and Divide
// MUL operations: single-cycle combinational (1/cycle throughput), like ALU.
// DIV operations: iterative (65 cycles for RV64), non-blocking — the core
// holds at most one outstanding DIV in a scoreboard slot (see rv64xo3_top)
// while independent instructions keep flowing.

import rv64xo3_pkg::*;
module rv64xo3_muldiv (
    input logic clk_i,
    input logic rst_ni,

    // DIV accept pulse from top (single cycle per DIV; MUL needs no start).
    input logic                                start_i,
    input rv64xo3_pkg::muldiv_op_e            op_i,
    input logic                     [XLEN-1:0] a_i,
    input logic                     [XLEN-1:0] b_i,

    // MUL: combinational result for the live inputs (same contract as ALU).
    output logic [XLEN-1:0] mul_result_o,
    // DIV: engine result + single-cycle completion pulse + busy.
    output logic [XLEN-1:0] div_result_o,
    output logic            div_valid_o,
    output logic            div_busy_o
);

  // Operation classes
  logic is_mul_op;
  assign is_mul_op = (op_i == MD_MUL) || (op_i == MD_MULH) || (op_i == MD_MULHSU) ||
                     (op_i == MD_MULHU) || (op_i == MD_MULW);

  //--------------------------------------------------------------------------
  // Combinational multiply (single-cycle, same contract as the ALU)
  //--------------------------------------------------------------------------
  logic [127:0] mul_product;
  always_comb begin
    case (op_i)
      MD_MUL, MD_MULH:  mul_product = $signed(a_i) * $signed(b_i);
      MD_MULHSU:        mul_product = $signed(a_i) * $signed({1'b0, b_i});
      MD_MULHU:         mul_product = a_i * b_i;
      MD_MULW:          mul_product = 128'($signed(a_i[31:0]) * $signed(b_i[31:0]));
      default:          mul_product = '0;
    endcase
  end

  always_comb begin
    case (op_i)
      MD_MUL:    mul_result_o = mul_product[XLEN-1:0];
      MD_MULH:   mul_result_o = mul_product[2*XLEN-1:XLEN];
      MD_MULHSU: mul_result_o = mul_product[2*XLEN-1:XLEN];
      MD_MULHU:  mul_result_o = mul_product[2*XLEN-1:XLEN];
      MD_MULW:   mul_result_o = {{32{mul_product[31]}}, mul_product[31:0]};
      default:   mul_result_o = '0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Iterative divider (non-blocking; one outstanding operation)
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    DIV_COMPUTE,
    DONE
  } state_e;

  state_e state, state_next;

  //--------------------------------------------------------------------------
  // Internal Registers (divider only)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] dividend;  // Working dividend for division
  logic [XLEN-1:0] divisor;  // Divisor
  logic [XLEN-1:0] quotient;  // Quotient accumulator
  logic [XLEN-1:0] remainder;  // Remainder
  logic [XLEN:0] temp_remainder;  // 65-bit temporary for division (RV64)
  logic [6:0] cycle_cnt;  // Cycle counter (7 bits for 64-bit division)
  rv64xo3_pkg::muldiv_op_e op_reg;  // Registered operation
  logic a_neg, b_neg;  // Latched issue-time sign flags (from a_reg/b_reg)
  logic a_neg_issue, b_neg_issue;  // Live issue-time signs (IDLE setup only)
  // Latched operands: a_i/b_i come from forwarding muxes and may switch
  // mid-operation as older instructions drain. All completion-time logic
  // (sign correction, div-by-zero, overflow) must use issue-time values.
  logic [XLEN-1:0] a_reg, b_reg;
  logic [XLEN-1:0] a_abs, b_abs;  // Absolute values (from live inputs at issue)

  // Division intermediate signals
  logic [  XLEN:0] div_rem_diff;
  logic [XLEN-1:0] div_rem_shifted;


  //--------------------------------------------------------------------------
  // Sign Handling
  //--------------------------------------------------------------------------
  // a_abs/b_abs sample the live inputs: only valid in IDLE at issue time,
  // when the pipeline holds the true operands. a_neg/b_neg below are the
  // latched issue-time signs used by all completion-time correction.
  assign a_neg_issue = a_i[XLEN-1];
  assign b_neg_issue = b_i[XLEN-1];
  assign a_neg = a_reg[XLEN-1];
  assign b_neg = b_reg[XLEN-1];
  assign a_abs = a_neg_issue ? (~a_i + 1'b1) : a_i;
  assign b_abs = b_neg_issue ? (~b_i + 1'b1) : b_i;

  //--------------------------------------------------------------------------
  // Division Logic (Combinational)
  //--------------------------------------------------------------------------
  always_comb begin
    div_rem_shifted = {remainder[XLEN-2:0], dividend[XLEN-1]};
    div_rem_diff    = {1'b0, div_rem_shifted} - {1'b0, divisor};
  end

  //--------------------------------------------------------------------------
  // State Machine
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
        // Only DIV operations occupy the engine; MUL is combinational.
        // DONE always returns to IDLE (even with start held) so a waiting
        // DIV issues cleanly from IDLE with a fresh operand latch.
        if (start_i && !is_mul_op) begin
          case (op_i)
            MD_DIV, MD_DIVU, MD_REM, MD_REMU,
            MD_DIVW, MD_DIVUW, MD_REMW, MD_REMUW: state_next = DIV_COMPUTE;
            default:                              state_next = IDLE;
          endcase
        end
      end
      DIV_COMPUTE: begin
        if (cycle_cnt == 7'd63) begin  // RV64: 63 cycles for 64-bit division
          state_next = DONE;
        end
      end
      DONE: begin
        state_next = IDLE;
      end
      default: state_next = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // Computation Logic (divider only)
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dividend  <= '0;
      divisor   <= '0;
      quotient  <= '0;
      remainder <= '0;
      temp_remainder <= '0;
      cycle_cnt <= '0;
      op_reg    <= MD_MUL;
      a_reg     <= '0;
      b_reg     <= '0;
    end else begin
      case (state)
        IDLE: begin
          if (start_i && !is_mul_op) begin
            op_reg    <= op_i;
            a_reg     <= a_i;
            b_reg     <= b_i;
            cycle_cnt <= '0;

            case (op_i)
              // Division setup
              MD_DIV, MD_REM: begin
                dividend  <= a_abs;
                divisor   <= b_abs;
                quotient  <= '0;
                remainder <= '0;
              end
              MD_DIVU, MD_REMU: begin
                dividend  <= a_i;
                divisor   <= b_i;
                quotient  <= '0;
                remainder <= '0;
              end
              // RV64M: 32-bit Division (DIVW, REMW)
              MD_DIVW, MD_REMW: begin
                // Use absolute values of 32-bit operands
                dividend  <= a_i[31] ? (~{{32{a_i[31]}}, a_i[31:0]} + 1'b1) : {{32{a_i[31]}}, a_i[31:0]};
                divisor   <= b_i[31] ? (~{{32{b_i[31]}}, b_i[31:0]} + 1'b1) : {{32{b_i[31]}}, b_i[31:0]};
                // Wait, logic above is creating ABS of 64-bit sign-extended version.
                // Which is same as ABS of 32-bit sign extended to 64. Correct.
                quotient  <= '0;
                remainder <= '0;
              end
              MD_DIVUW, MD_REMUW: begin
                // Unsigned 32-bit division
                dividend  <= {32'b0, a_i[31:0]};
                divisor   <= {32'b0, b_i[31:0]};
                quotient  <= '0;
                remainder <= '0;
              end
              default: ;
            endcase
          end
        end
        DIV_COMPUTE: begin
          cycle_cnt <= cycle_cnt + 1'b1;

          // Check if divisor fits
          if (!div_rem_diff[XLEN]) begin
            // It fits: update remainder and shift 1 into quotient
            remainder <= div_rem_diff[XLEN-1:0];
            quotient  <= {quotient[XLEN-2:0], 1'b1};
          end else begin
            // Doesn't fit: keep remainder and shift 0 into quotient
            remainder <= div_rem_shifted;
            quotient  <= {quotient[XLEN-2:0], 1'b0};
          end

          dividend <= {dividend[XLEN-2:0], 1'b0};
        end

        DONE: begin
          cycle_cnt <= '0;
        end

        default: ;
      endcase
    end
  end

  //--------------------------------------------------------------------------
  // Result Selection
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] div_result;
  logic [XLEN-1:0] rem_result;
  logic [XLEN-1:0] raw_div_res;
  logic [XLEN-1:0] raw_rem_res;

  // Handle division by zero and overflow
  logic div_by_zero;
  logic div_overflow;
  
  // Need separate overflow check for 32-bit division?
  // User spec: DIVW overflow happens if -2^31 / -1
  // -2^31 = 0x80000000. -1 = 0xFFFFFFFF.
  // 64-bit operands: 0xFFFFFFFF80000000 / 0xFFFFFFFFFFFFFFFF
  // Logic below checks full 64-bit values.
  
  assign div_by_zero  = (op_reg == MD_DIVW || op_reg == MD_DIVUW || op_reg == MD_REMW || op_reg == MD_REMUW) ?
                        (b_reg[31:0] == 32'd0) : (divisor == '0); // Logic depends on if divisor was loaded with 0. 
                        // Wait, divisor register holds ABS value. If input was 0, divisor is 0.
                        // So checking (divisor == 0) is sufficient for all signed/unsigned cases?
                        // Yes, abs(0) = 0.
                        // But need to be careful about 32-bit vs 64-bit.
                        // For 32-bit, we loaded divisor with abs(b[31:0]). If b[31:0]==0, divisor=0. Correct.

  // Reuse existing logic for simplicity, but refine div_overflow
  assign div_overflow = ((op_reg == MD_DIV) && (a_reg == 64'h8000_0000_0000_0000) && (b_reg == 64'hFFFF_FFFF_FFFF_FFFF)) ||
                        ((op_reg == MD_DIVW) && (a_reg[31:0] == 32'h8000_0000) && (b_reg[31:0] == 32'hFFFF_FFFF));

  // Sign correction for signed division
  always_comb begin
    // For 32-bit ops, we need result sign extension
    logic is_32bit_div;
    logic w_a_neg_all, w_b_neg_all, w_a_neg_rem;
    
    is_32bit_div = (op_reg == MD_DIVW || op_reg == MD_REMW || op_reg == MD_DIVUW || op_reg == MD_REMUW);
    raw_div_res = '0;
    raw_rem_res = '0;
    w_a_neg_all = a_reg[31];
    w_b_neg_all = b_reg[31];
    w_a_neg_rem = a_reg[31];

    if ((divisor == '0) && !div_by_zero) begin
        // Fallback if logic mismatch, but divisor==0 catches it.
        // Actually divisor is register.
    end

    if (divisor == '0) begin // divide by zero
        if (is_32bit_div) begin
            div_result = 64'hFFFF_FFFF_FFFF_FFFF;
            // Remainder is the 32-bit dividend, sign-extended to XLEN
            // (even for unsigned W ops: riscv-tests remuw #8 expects
            // 0xFFFFFFFF80000000, not zero-extended).
            rem_result = {{32{a_reg[31]}}, a_reg[31:0]}; // Dividend (sign-extended)
        end else begin
            div_result = 64'hFFFF_FFFF_FFFF_FFFF; 
            rem_result = a_reg;
        end
    end else if (div_overflow) begin
        if (op_reg == MD_DIVW) begin
             div_result = 64'hFFFF_FFFF_8000_0000; // -2^31 sign extended
             rem_result = '0;
        end else begin
             div_result = 64'h8000_0000_0000_0000;
             rem_result = '0;
        end
    end else begin
      case (op_reg)
        MD_DIV: begin
          div_result = (a_neg ^ b_neg) ? (~quotient + 1'b1) : quotient;
          rem_result = a_neg ? (~remainder + 1'b1) : remainder;
        end
        MD_DIVU: begin
          div_result = quotient;
          rem_result = remainder;
        end
        MD_REM: begin
          div_result = quotient;
          rem_result = a_neg ? (~remainder + 1'b1) : remainder;
        end
        MD_REMU: begin
          div_result = quotient;
          rem_result = remainder;
        end
        // RV64M 32-bit
        MD_DIVW: begin
            raw_div_res = (w_a_neg_all ^ w_b_neg_all) ? (~quotient + 1'b1) : quotient;
            raw_rem_res = w_a_neg_all ? (~remainder + 1'b1) : remainder;
            div_result = {{32{raw_div_res[31]}}, raw_div_res[31:0]}; // Sign extend 32-bit result
            rem_result = {{32{raw_rem_res[31]}}, raw_rem_res[31:0]};
        end
        MD_DIVUW: begin
            div_result = {{32{quotient[31]}}, quotient[31:0]}; // Sign extend result (even for unsigned div, result is 32-bit signed in 64-bit reg)
            rem_result = {{32{remainder[31]}}, remainder[31:0]};
        end
        MD_REMW: begin
             raw_rem_res = w_a_neg_rem ? (~remainder + 1'b1) : remainder;
             div_result = quotient; // Don't care
             rem_result = {{32{raw_rem_res[31]}}, raw_rem_res[31:0]};
        end
        MD_REMUW: begin
             div_result = quotient;
             rem_result = {{32{remainder[31]}}, remainder[31:0]};
        end
        default: begin
          div_result = quotient;
          rem_result = remainder;
        end
      endcase
    end
  end

  // DIV result mux over the latched engine state. MUL never reads this
  // path (it uses mul_result_o); the two completions are independent.
  always_comb begin
    case (op_reg)
      MD_DIV:    div_result_o = div_result;
      MD_DIVU:   div_result_o = div_result;
      MD_REM:    div_result_o = rem_result;
      MD_REMU:   div_result_o = rem_result;
      MD_DIVW:   div_result_o = div_result;
      MD_DIVUW:  div_result_o = div_result;
      MD_REMW:   div_result_o = rem_result;
      MD_REMUW:  div_result_o = rem_result;
      default:   div_result_o = '0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Status Outputs
  //--------------------------------------------------------------------------
  // DONE pulses for exactly one cycle; top injects the writeback on it.
  // DONE always returns to IDLE (even with start held) so back-to-back DIVs
  // issue cleanly from IDLE with a fresh latch each time.
  assign div_valid_o = (state == DONE);
  assign div_busy_o  = (state != IDLE);

endmodule : rv64xo3_muldiv
