// IronCore MulDiv Unit - Multiply and Divide
// Iterative implementation for RV64IM extension
// MUL operations: 2 cycles
// DIV operations: 65 cycles (one bit per cycle + result) for RV64

import ironcore_pkg::*;
module ironcore_muldiv (
    input logic clk_i,
    input logic rst_ni,

    input logic                                start_i,
    input ironcore_pkg::muldiv_op_e            op_i,
    input logic                     [XLEN-1:0] a_i,
    input logic                     [XLEN-1:0] b_i,

    output logic [XLEN-1:0] result_o,
    output logic            valid_o,
    output logic            busy_o
);

  //--------------------------------------------------------------------------
  // State Machine
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    MUL_COMPUTE,
    DIV_COMPUTE,
    DONE
  } state_e;

  state_e state, state_next;

  //--------------------------------------------------------------------------
  // Internal Registers
  //--------------------------------------------------------------------------
  logic [127:0] product;  // For 64x64 multiplication result (RV64)
  logic [XLEN-1:0] dividend;  // Working dividend for division
  logic [XLEN-1:0] divisor;  // Divisor
  logic [XLEN-1:0] quotient;  // Quotient accumulator
  logic [XLEN-1:0] remainder;  // Remainder
  logic [XLEN:0] temp_remainder;  // 65-bit temporary for division (RV64)
  logic [6:0] cycle_cnt;  // Cycle counter (7 bits for 64-bit division)
  ironcore_pkg::muldiv_op_e op_reg;  // Registered operation
  logic a_neg, b_neg;  // Sign flags
  logic [XLEN-1:0] a_abs, b_abs;  // Absolute values

  // Division intermediate signals
  logic [  XLEN:0] div_rem_diff;
  logic [XLEN-1:0] div_rem_shifted;


  //--------------------------------------------------------------------------
  // Sign Handling
  //--------------------------------------------------------------------------
  assign a_neg = a_i[XLEN-1];
  assign b_neg = b_i[XLEN-1];
  assign a_abs = a_neg ? (~a_i + 1'b1) : a_i;
  assign b_abs = b_neg ? (~b_i + 1'b1) : b_i;

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
        if (start_i) begin
          case (op_i)
            MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_MULW: state_next = MUL_COMPUTE;
            MD_DIV, MD_DIVU, MD_REM, MD_REMU,
            MD_DIVW, MD_DIVUW, MD_REMW, MD_REMUW: state_next = DIV_COMPUTE;
            default:                              state_next = IDLE;
          endcase
        end
      end
      MUL_COMPUTE: begin
        if (cycle_cnt == 6'd1) begin
          state_next = DONE;
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
  // Computation Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      product   <= '0;
      dividend  <= '0;
      divisor   <= '0;
      quotient  <= '0;
      remainder <= '0;
      temp_remainder <= '0;
      cycle_cnt <= '0;
      op_reg    <= MD_MUL;
    end else begin
      case (state)
        IDLE: begin
          if (start_i) begin
            op_reg    <= op_i;
            cycle_cnt <= '0;

            case (op_i)
              // Signed x Signed multiplication (64x64 → 128-bit)
              MD_MUL, MD_MULH: begin
                product <= $signed(a_i) * $signed(b_i);
              end
              // Signed x Unsigned multiplication
              MD_MULHSU: begin
                product <= $signed(a_i) * $signed({1'b0, b_i});
              end
              // Unsigned x Unsigned multiplication
              MD_MULHU: begin
                product <= a_i * b_i;
              end
              // RV64M: 32-bit Multiply (MULW)
              MD_MULW: begin
                  // Multiply lower 32 bits, result is sign-extended 32-bit product
                  product <= $signed(a_i[31:0]) * $signed(b_i[31:0]);
              end
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
        // ... (MUL_COMPUTE and DIV_COMPUTE logic unchanged)
        MUL_COMPUTE: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          // Multiplication completes in pipeline (combinational result ready)
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

  // Handle division by zero and overflow
  logic div_by_zero;
  logic div_overflow;
  
  // Need separate overflow check for 32-bit division?
  // User spec: DIVW overflow happens if -2^31 / -1
  // -2^31 = 0x80000000. -1 = 0xFFFFFFFF.
  // 64-bit operands: 0xFFFFFFFF80000000 / 0xFFFFFFFFFFFFFFFF
  // Logic below checks full 64-bit values.
  
  assign div_by_zero  = (op_reg == MD_DIVW || op_reg == MD_DIVUW || op_reg == MD_REMW || op_reg == MD_REMUW) ? 
                        (b_i[31:0] == 32'd0) : (divisor == '0); // Logic depends on if divisor was loaded with 0. 
                        // Wait, divisor register holds ABS value. If input was 0, divisor is 0.
                        // So checking (divisor == 0) is sufficient for all signed/unsigned cases?
                        // Yes, abs(0) = 0.
                        // But need to be careful about 32-bit vs 64-bit.
                        // For 32-bit, we loaded divisor with abs(b[31:0]). If b[31:0]==0, divisor=0. Correct.

  // Reuse existing logic for simplicity, but refine div_overflow
  assign div_overflow = ((op_reg == MD_DIV) && (a_i == 64'h8000_0000_0000_0000) && (b_i == 64'hFFFF_FFFF_FFFF_FFFF)) ||
                        ((op_reg == MD_DIVW) && (a_i[31:0] == 32'h8000_0000) && (b_i[31:0] == 32'hFFFF_FFFF));

  // Sign correction for signed division
  always_comb begin
    // For 32-bit ops, we need result sign extension
    logic [XLEN-1:0] raw_div_res, raw_rem_res;
    logic is_32bit_div;
    
    is_32bit_div = (op_reg == MD_DIVW || op_reg == MD_REMW || op_reg == MD_DIVUW || op_reg == MD_REMUW);

    if ((divisor == '0) && !div_by_zero) begin
        // Fallback if logic mismatch, but divisor==0 catches it.
        // Actually divisor is register.
    end

    if (divisor == '0) begin // divide by zero
        if (is_32bit_div) begin
            div_result = 64'hFFFF_FFFF_FFFF_FFFF;
            rem_result = {{32{a_i[31]}}, a_i[31:0]}; // Dividend (sign-extended)
            if (op_reg == MD_DIVUW || op_reg == MD_REMUW) begin
               rem_result = {32'b0, a_i[31:0]}; // Unsigned dividend
            end
        end else begin
            div_result = 64'hFFFF_FFFF_FFFF_FFFF; 
            rem_result = a_i;
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
            logic w_a_neg, w_b_neg;
            w_a_neg = a_i[31];
            w_b_neg = b_i[31];
            raw_div_res = (w_a_neg ^ w_b_neg) ? (~quotient + 1'b1) : quotient;
            raw_rem_res = w_a_neg ? (~remainder + 1'b1) : remainder;
            div_result = {{32{raw_div_res[31]}}, raw_div_res[31:0]}; // Sign extend 32-bit result
            rem_result = {{32{raw_rem_res[31]}}, raw_rem_res[31:0]};
        end
        MD_DIVUW: begin
            div_result = {{32{quotient[31]}}, quotient[31:0]}; // Sign extend result (even for unsigned div, result is 32-bit signed in 64-bit reg)
            rem_result = {{32{remainder[31]}}, remainder[31:0]};
        end
        MD_REMW: begin
             logic w_a_neg;
             w_a_neg = a_i[31];
             raw_rem_res = w_a_neg ? (~remainder + 1'b1) : remainder;
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

  always_comb begin
    case (op_reg)
      MD_MUL:    result_o = product[XLEN-1:0];
      MD_MULH:   result_o = product[2*XLEN-1:XLEN];
      MD_MULHSU: result_o = product[2*XLEN-1:XLEN];
      MD_MULHU:  result_o = product[2*XLEN-1:XLEN];
      // RV64M
      MD_MULW:   result_o = {{32{product[31]}}, product[31:0]}; // Sign-extend lower 32 bits
      MD_DIV:    result_o = div_result;
      MD_DIVU:   result_o = div_result;
      MD_REM:    result_o = rem_result;
      MD_REMU:   result_o = rem_result;
      MD_DIVW:   result_o = div_result;
      MD_DIVUW:  result_o = div_result;
      MD_REMW:   result_o = rem_result;
      MD_REMUW:  result_o = rem_result;
      default:   result_o = '0;
    endcase
  end

  //--------------------------------------------------------------------------
  // Status Outputs
  //--------------------------------------------------------------------------
  assign valid_o = (state == DONE);
  assign busy_o  = (state != IDLE) && (state != DONE);

endmodule : ironcore_muldiv
