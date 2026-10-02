// RV64C integer instruction expansion. Floating-point encodings are illegal.
// Integration must preserve the original 16-bit instruction for mtval and
// carry length=2 for sequential PCs and JALR links; expansion alone is not C.
module rv64xo3_rvc (
    input  logic [15:0] instr_i,
    output logic [31:0] instr_o,
    output logic illegal_o
);
  logic [4:0] rd, rs2, rp, sp;
  logic [11:0] imm;
  logic [11:1] jump;
  logic [8:1] branch;
  assign rd = instr_i[11:7];
  assign rs2 = instr_i[6:2];
  assign rp = {2'b01, instr_i[9:7]};
  assign sp = {2'b01, instr_i[4:2]};

  function automatic [31:0] itype(input logic [11:0] value,
      input logic [4:0] src, input logic [2:0] fn,
      input logic [4:0] dst, input logic [6:0] op);
    itype = {value, src, fn, dst, op};
  endfunction
  function automatic [31:0] store_insn(input logic [11:0] value,
      input logic [4:0] src, input logic [4:0] base, input logic [2:0] fn);
    store_insn = {value[11:5], src, base, fn, value[4:0], 7'b0100011};
  endfunction

  always_comb begin
    instr_o = 32'h00000013;
    illegal_o = 1'b0;
    imm = {{6{instr_i[12]}}, instr_i[12], instr_i[6:2]};
    jump = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6],
            instr_i[7], instr_i[2], instr_i[11], instr_i[5:3]};
    branch = {instr_i[12], instr_i[6:5], instr_i[2], instr_i[11:10],
              instr_i[4:3]};
    case (instr_i[1:0])
      2'b00: case (instr_i[15:13])
        3'b000: begin // ADDI4SPN
          imm = {2'b00, instr_i[10:7], instr_i[12:11], instr_i[5], instr_i[6], 2'b00};
          instr_o = itype(imm, 5'd2, 3'b000, sp, 7'b0010011);
          illegal_o = (imm == 0);
        end
        3'b010, 3'b110: begin // LW / SW
          imm = {5'b0, instr_i[5], instr_i[12:10], instr_i[6], 2'b00};
          instr_o = instr_i[15] ? store_insn(imm, sp, rp, 3'b010) :
                                  itype(imm, rp, 3'b010, sp, 7'b0000011);
        end
        3'b011, 3'b111: begin // LD / SD
          imm = {4'b0, instr_i[6:5], instr_i[12:10], 3'b000};
          instr_o = instr_i[15] ? store_insn(imm, sp, rp, 3'b011) :
                                  itype(imm, rp, 3'b011, sp, 7'b0000011);
        end
        default: illegal_o = 1'b1;
      endcase
      2'b01: case (instr_i[15:13])
        3'b000: instr_o = itype(imm, rd, 3'b000, rd, 7'b0010011); // ADDI / NOP
        3'b001: begin // ADDIW (RV64, not RV32 JAL)
          instr_o = itype(imm, rd, 3'b000, rd, 7'b0011011);
          illegal_o = (rd == 0);
        end
        3'b010: instr_o = itype(imm, 5'd0, 3'b000, rd, 7'b0010011); // LI
        3'b011: begin
          if (rd == 2) begin // ADDI16SP
            imm = {{3{instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2], instr_i[6], 4'b0};
            instr_o = itype(imm, rd, 3'b000, rd, 7'b0010011);
          end else begin // LUI (rd=0 is a hint)
            instr_o = {{14{instr_i[12]}}, instr_i[12], instr_i[6:2], rd, 7'b0110111};
          end
          illegal_o = ({instr_i[12], instr_i[6:2]} == 0);
        end
        3'b100: case (instr_i[11:10])
          2'b00, 2'b01: begin // SRLI / SRAI
            imm = {1'b0, instr_i[10], 4'b0, instr_i[12], instr_i[6:2]};
            instr_o = itype(imm, rp, 3'b101, rp, 7'b0010011);
          end
          2'b10: instr_o = itype(imm, rp, 3'b111, rp, 7'b0010011); // ANDI
          2'b11: begin
            case (instr_i[6:5])
              2'b00: instr_o = {7'b0100000, sp, rp, 3'b000, rp, 7'b0110011};
              2'b01: instr_o = {7'b0000000, sp, rp, 3'b100, rp, 7'b0110011};
              2'b10: instr_o = {7'b0000000, sp, rp, 3'b110, rp, 7'b0110011};
              2'b11: instr_o = {7'b0000000, sp, rp, 3'b111, rp, 7'b0110011};
            endcase
            if (instr_i[12]) begin // SUBW / ADDW; other encodings reserved
              instr_o = {1'b0, !instr_i[5], 5'b0, sp, rp, 3'b000, rp, 7'b0111011};
              illegal_o = instr_i[6];
            end
          end
        endcase
        3'b101: // J -> JAL x0; sign extension of the CJ displacement
          instr_o = {jump[11], jump[10:1], jump[11], {8{jump[11]}}, 5'd0, 7'b1101111};
        3'b110, 3'b111: // BEQZ / BNEZ
          instr_o = {{4{branch[8]}}, branch[7:5], 5'd0, rp,
                     2'b00, instr_i[13], branch[4:1], branch[8], 7'b1100011};
        default: illegal_o = 1'b1;
      endcase
      2'b10: case (instr_i[15:13])
        3'b000: instr_o = itype({6'b0, instr_i[12], instr_i[6:2]},
                                rd, 3'b001, rd, 7'b0010011); // SLLI
        3'b010: begin // LWSP
          imm = {4'b0, instr_i[3:2], instr_i[12], instr_i[6:4], 2'b00};
          instr_o = itype(imm, 5'd2, 3'b010, rd, 7'b0000011);
          illegal_o = (rd == 0);
        end
        3'b011: begin // LDSP
          imm = {3'b0, instr_i[4:2], instr_i[12], instr_i[6:5], 3'b000};
          instr_o = itype(imm, 5'd2, 3'b011, rd, 7'b0000011);
          illegal_o = (rd == 0);
        end
        3'b100: begin
          if (rs2 == 0) begin
            if (instr_i[12] && rd == 0) instr_o = 32'h00100073; // EBREAK
            else begin // JR / JALR: caller must override link increment to 2
              instr_o = itype(12'b0, rd, 3'b000, {4'b0, instr_i[12]}, 7'b1100111);
              illegal_o = (rd == 0);
            end
          end else // MV / ADD (rd=0 are hints)
            instr_o = {7'b0, rs2, (instr_i[12] ? rd : 5'd0), 3'b000, rd, 7'b0110011};
        end
        3'b110: begin // SWSP
          imm = {4'b0, instr_i[8:7], instr_i[12:9], 2'b00};
          instr_o = store_insn(imm, rs2, 5'd2, 3'b010);
        end
        3'b111: begin // SDSP
          imm = {3'b0, instr_i[9:7], instr_i[12:10], 3'b000};
          instr_o = store_insn(imm, rs2, 5'd2, 3'b011);
        end
        default: illegal_o = 1'b1;
      endcase
      default: illegal_o = 1'b1; // 32-bit instructions bypass this module
    endcase
    if (illegal_o) instr_o = 32'b0;
  end
endmodule
