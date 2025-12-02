// IronCore Decoder - Instruction Decode Logic
// Decodes RV64IM instructions and generates control signals

import ironcore_pkg::*;
module ironcore_decoder (
    input logic [ILEN-1:0] instr_i,

    // Immediate output
    output logic [XLEN-1:0] imm_o,

    // ALU control
    output ironcore_pkg::alu_op_e    alu_op_o,
    output ironcore_pkg::branch_op_e branch_op_o,
    output ironcore_pkg::muldiv_op_e muldiv_op_o,
    output logic                     alu_src_o,    // 0: rs2, 1: imm

    // Memory control
    output logic                     mem_read_o,
    output logic                     mem_write_o,
    output ironcore_pkg::mem_width_e mem_width_o,
    output logic                     mem_unsigned_o,

    // Register control
    output logic reg_write_o,

    // Branch/jump control
    output logic is_branch_o,
    output logic is_jal_o,
    output logic is_jalr_o,

    // M extension
    output logic is_muldiv_o,

    // CSR control
    output logic        is_csr_o,
    output logic [11:0] csr_addr_o,
    output logic [ 2:0] csr_op_o,

    // System instructions
    output logic is_ecall_o,
    output logic is_ebreak_o,
    output logic is_mret_o,

    // Special instructions
    output logic is_auipc_o,

    // Exception
    output logic illegal_instr_o
);

  //--------------------------------------------------------------------------
  // Instruction Field Extraction
  //--------------------------------------------------------------------------
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instr_i[6:0];
  assign funct3 = instr_i[14:12];
  assign funct7 = instr_i[31:25];

  //--------------------------------------------------------------------------
  // Immediate Generation
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] imm_i;  // I-type
  logic [XLEN-1:0] imm_s;  // S-type
  logic [XLEN-1:0] imm_b;  // B-type
  logic [XLEN-1:0] imm_u;  // U-type
  logic [XLEN-1:0] imm_j;  // J-type

  // I-type immediate: sign-extended 12-bit to 64-bit
  assign imm_i = {{52{instr_i[31]}}, instr_i[31:20]};

  // S-type immediate: sign-extended 12-bit from [31:25] and [11:7]
  assign imm_s = {{52{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

  // B-type immediate: sign-extended 13-bit (shifted left by 1)
  assign imm_b = {{51{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

  // U-type immediate: upper 20 bits, lower 12 bits zero, sign-extended to 64-bit
  assign imm_u = {{32{instr_i[31]}}, instr_i[31:12], 12'b0};

  // J-type immediate: sign-extended 21-bit (shifted left by 1)
  assign imm_j = {
    {43{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0
  };

  //--------------------------------------------------------------------------
  // Main Decode Logic
  //--------------------------------------------------------------------------
  always_comb begin
    // Default values
    imm_o           = '0;
    alu_op_o        = ALU_ADD;
    branch_op_o     = BR_NONE;
    muldiv_op_o     = MD_MUL;
    alu_src_o       = 1'b0;
    mem_read_o      = 1'b0;
    mem_write_o     = 1'b0;
    mem_width_o     = MEM_WORD;
    mem_unsigned_o  = 1'b0;
    reg_write_o     = 1'b0;
    is_branch_o     = 1'b0;
    is_jal_o        = 1'b0;
    is_jalr_o       = 1'b0;
    is_muldiv_o     = 1'b0;
    is_csr_o        = 1'b0;
    csr_addr_o      = instr_i[31:20];
    csr_op_o        = funct3;
    is_ecall_o      = 1'b0;
    is_ebreak_o     = 1'b0;
    is_mret_o       = 1'b0;
    is_auipc_o      = 1'b0;
    illegal_instr_o = 1'b0;

    case (opcode)
      //----------------------------------------------------------------------
      // LUI - Load Upper Immediate
      //----------------------------------------------------------------------
      OP_LUI: begin
        imm_o       = imm_u;
        alu_op_o    = ALU_PASS_B;
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
      end

      //----------------------------------------------------------------------
      // AUIPC - Add Upper Immediate to PC
      //----------------------------------------------------------------------
      OP_AUIPC: begin
        imm_o       = imm_u;
        alu_op_o    = ALU_ADD;
        alu_src_o   = 1'b1;  // ALU will add PC + imm (handled in EX)
        reg_write_o = 1'b1;
        is_auipc_o  = 1'b1;
      end

      //----------------------------------------------------------------------
      // JAL - Jump and Link
      //----------------------------------------------------------------------
      OP_JAL: begin
        imm_o       = imm_j;
        alu_op_o    = ALU_ADD;
        reg_write_o = 1'b1;  // rd = PC + 4
        is_jal_o    = 1'b1;
      end

      //----------------------------------------------------------------------
      // JALR - Jump and Link Register
      //----------------------------------------------------------------------
      OP_JALR: begin
        imm_o       = imm_i;
        alu_op_o    = ALU_ADD;
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;  // rd = PC + 4
        is_jalr_o   = 1'b1;
        if (funct3 != 3'b000) begin
          illegal_instr_o = 1'b1;
        end
      end

      //----------------------------------------------------------------------
      // Branches
      //----------------------------------------------------------------------
      OP_BRANCH: begin
        imm_o       = imm_b;
        is_branch_o = 1'b1;
        case (funct3)
          FUNCT3_BEQ:  branch_op_o = BR_EQ;
          FUNCT3_BNE:  branch_op_o = BR_NE;
          FUNCT3_BLT:  branch_op_o = BR_LT;
          FUNCT3_BGE:  branch_op_o = BR_GE;
          FUNCT3_BLTU: branch_op_o = BR_LTU;
          FUNCT3_BGEU: branch_op_o = BR_GEU;
          default:     illegal_instr_o = 1'b1;
        endcase
      end

      //----------------------------------------------------------------------
      // Loads
      //----------------------------------------------------------------------
      OP_LOAD: begin
        imm_o       = imm_i;
        alu_op_o    = ALU_ADD;
        alu_src_o   = 1'b1;
        mem_read_o  = 1'b1;
        reg_write_o = 1'b1;
        case (funct3)
          FUNCT3_LB: begin
            mem_width_o    = MEM_BYTE;
            mem_unsigned_o = 1'b0;
          end
          FUNCT3_LH: begin
            mem_width_o    = MEM_HALF;
            mem_unsigned_o = 1'b0;
          end
          FUNCT3_LW: begin
            mem_width_o    = MEM_WORD;
            mem_unsigned_o = 1'b0;
          end
          FUNCT3_LBU: begin
            mem_width_o    = MEM_BYTE;
            mem_unsigned_o = 1'b1;
          end
          FUNCT3_LHU: begin
            mem_width_o    = MEM_HALF;
            mem_unsigned_o = 1'b1;
          end
          3'b110: begin  // LWU - RV64I load word unsigned
            mem_width_o    = MEM_WORD;
            mem_unsigned_o = 1'b1;
          end
          3'b011: begin  // LD - RV64I load doubleword
            mem_width_o    = MEM_DWORD;
            mem_unsigned_o = 1'b0;
          end
          default: illegal_instr_o = 1'b1;
        endcase
      end

      //----------------------------------------------------------------------
      // Stores
      //----------------------------------------------------------------------
      OP_STORE: begin
        imm_o       = imm_s;
        alu_op_o    = ALU_ADD;
        alu_src_o   = 1'b1;
        mem_write_o = 1'b1;
        case (funct3)
          FUNCT3_SB: mem_width_o = MEM_BYTE;
          FUNCT3_SH: mem_width_o = MEM_HALF;
          FUNCT3_SW: mem_width_o = MEM_WORD;
          3'b011:    mem_width_o = MEM_DWORD;  // SD - RV64I store doubleword
          default:   illegal_instr_o = 1'b1;
        endcase
      end

      //----------------------------------------------------------------------
      // ALU Immediate Operations
      //----------------------------------------------------------------------
      OP_OP_IMM: begin
        imm_o       = imm_i;
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
        case (funct3)
          FUNCT3_ADDI: alu_op_o = ALU_ADD;
          FUNCT3_SLTI: alu_op_o = ALU_SLT;
          FUNCT3_SLTIU: alu_op_o = ALU_SLTU;
          FUNCT3_XORI: alu_op_o = ALU_XOR;
          FUNCT3_ORI: alu_op_o = ALU_OR;
          FUNCT3_ANDI: alu_op_o = ALU_AND;
          FUNCT3_SLLI: begin
            alu_op_o = ALU_SLL;
            // RV64I: check bit [26] must be 0 (6-bit shamt uses bits [25:20])
            if (instr_i[26] != 1'b0) begin
              illegal_instr_o = 1'b1;
            end
          end
          FUNCT3_SRXI: begin
            if (instr_i[30] == 1'b0) begin
              alu_op_o = ALU_SRL;
            end else begin
              alu_op_o = ALU_SRA;
            end
            // RV64I: check bit [26] must be 0
            if (instr_i[26] != 1'b0) begin
              illegal_instr_o = 1'b1;
            end
          end
          default: illegal_instr_o = 1'b1;
        endcase
      end

      //----------------------------------------------------------------------
      // ALU Register Operations (including M extension)
      //----------------------------------------------------------------------
      OP_OP: begin
        reg_write_o = 1'b1;

        if (funct7 == 7'b0000001) begin
          // M extension
          is_muldiv_o = 1'b1;
          case (funct3)
            3'b000:  muldiv_op_o = ironcore_pkg::MD_MUL;
            3'b001:  muldiv_op_o = ironcore_pkg::MD_MULH;
            3'b010:  muldiv_op_o = ironcore_pkg::MD_MULHSU;
            3'b011:  muldiv_op_o = ironcore_pkg::MD_MULHU;
            3'b100:  muldiv_op_o = ironcore_pkg::MD_DIV;
            3'b101:  muldiv_op_o = ironcore_pkg::MD_DIVU;
            3'b110:  muldiv_op_o = ironcore_pkg::MD_REM;
            3'b111:  muldiv_op_o = ironcore_pkg::MD_REMU;
            default: muldiv_op_o = ironcore_pkg::MD_MUL;
          endcase
        end else begin
          // Base integer operations
          case (funct3)
            FUNCT3_ADD_SUB: begin
              if (funct7 == 7'b0000000) begin
                alu_op_o = ALU_ADD;
              end else if (funct7 == 7'b0100000) begin
                alu_op_o = ALU_SUB;
              end else begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_SLL: begin
              alu_op_o = ALU_SLL;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_SLT: begin
              alu_op_o = ALU_SLT;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_SLTU: begin
              alu_op_o = ALU_SLTU;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_XOR: begin
              alu_op_o = ALU_XOR;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_SRX: begin
              if (funct7 == 7'b0000000) begin
                alu_op_o = ALU_SRL;
              end else if (funct7 == 7'b0100000) begin
                alu_op_o = ALU_SRA;
              end else begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_OR: begin
              alu_op_o = ALU_OR;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            FUNCT3_AND: begin
              alu_op_o = ALU_AND;
              if (funct7 != 7'b0000000) begin
                illegal_instr_o = 1'b1;
              end
            end
            default: illegal_instr_o = 1'b1;
          endcase
        end
      end

      //----------------------------------------------------------------------
      // FENCE (treat as NOP for now)
      //----------------------------------------------------------------------
      OP_MISC_MEM: begin
        // FENCE is treated as NOP in this implementation
        if (funct3 != 3'b000) begin
          illegal_instr_o = 1'b1;
        end
      end

      //----------------------------------------------------------------------
      // System Instructions (ECALL, EBREAK, CSR, MRET)
      //----------------------------------------------------------------------
      OP_SYSTEM: begin
        if (funct3 == FUNCT3_PRIV) begin
          // ECALL, EBREAK, MRET, etc.
          case (instr_i[31:20])
            12'h000: is_ecall_o = 1'b1;  // ECALL
            12'h001: is_ebreak_o = 1'b1;  // EBREAK
            12'h302: is_mret_o = 1'b1;  // MRET
            default: illegal_instr_o = 1'b1;
          endcase
        end else begin
          // CSR instructions
          is_csr_o    = 1'b1;
          reg_write_o = 1'b1;
        end
      end

      //----------------------------------------------------------------------
      // RV64I: OP-IMM-32 (Word Immediate Operations)
      //----------------------------------------------------------------------
      OP_OP_IMM_32: begin
        imm_o       = imm_i;
        alu_src_o   = 1'b1;
        reg_write_o = 1'b1;
        case (funct3)
          3'b000: alu_op_o = ALU_ADDW;  // ADDIW
          3'b001: begin  // SLLIW
            alu_op_o = ALU_SLLW;
            if (funct7 != 7'b0000000) begin
              illegal_instr_o = 1'b1;
            end
          end
          3'b101: begin  // SRLIW / SRAIW
            if (funct7 == 7'b0000000) begin
              alu_op_o = ALU_SRLW;
            end else if (funct7 == 7'b0100000) begin
              alu_op_o = ALU_SRAW;
            end else begin
              illegal_instr_o = 1'b1;
            end
          end
          default: illegal_instr_o = 1'b1;
        endcase
      end

      //----------------------------------------------------------------------
      // RV64I: OP-32 (Word Register Operations)
      //----------------------------------------------------------------------
      OP_OP_32: begin
        reg_write_o = 1'b1;
        
        if (funct7 == 7'b0000001) begin
          // RV64M 32-bit operations
          is_muldiv_o = 1'b1;
          case (funct3)
            3'b000:  muldiv_op_o = ironcore_pkg::MD_MULW;
            3'b100:  muldiv_op_o = ironcore_pkg::MD_DIVW;
            3'b101:  muldiv_op_o = ironcore_pkg::MD_DIVUW;
            3'b110:  muldiv_op_o = ironcore_pkg::MD_REMW;
            3'b111:  muldiv_op_o = ironcore_pkg::MD_REMUW;
            default: illegal_instr_o = 1'b1;
          endcase
        end else begin
            case (funct3)
              3'b000: begin  // ADDW / SUBW
                if (funct7 == 7'b0000000) begin
                  alu_op_o = ALU_ADDW;
                end else if (funct7 == 7'b0100000) begin
                  alu_op_o = ALU_SUBW;
                end else begin
                  illegal_instr_o = 1'b1;
                end
              end
              3'b001: begin  // SLLW
                alu_op_o = ALU_SLLW;
                if (funct7 != 7'b0000000) begin
                  illegal_instr_o = 1'b1;
                end
              end
              3'b101: begin  // SRLW / SRAW
                if (funct7 == 7'b0000000) begin
                  alu_op_o = ALU_SRLW;
                end else if (funct7 == 7'b0100000) begin
                  alu_op_o = ALU_SRAW;
                end else begin
                  illegal_instr_o = 1'b1;
                end
              end
              default: illegal_instr_o = 1'b1;
            endcase
        end
      end

      //----------------------------------------------------------------------
      // Illegal instruction
      //----------------------------------------------------------------------
      default: begin
        illegal_instr_o = 1'b1;
      end
    endcase
  end

endmodule : ironcore_decoder
