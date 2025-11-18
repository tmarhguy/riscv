// IronCore Package - Common Types and Definitions
// RV64IM 5-Stage Pipelined Processor

package ironcore_pkg;

  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------
  parameter int XLEN = 64;  // RV64IM: 64-bit architecture
  parameter int ILEN = 32;
  parameter int REG_ADDR_W = 5;
  parameter int NUM_REGS = 32;

  //--------------------------------------------------------------------------
  // Opcodes (RV32I + M)
  //--------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OP_LUI      = 7'b0110111,
    OP_AUIPC    = 7'b0010111,
    OP_JAL      = 7'b1101111,
    OP_JALR     = 7'b1100111,
    OP_BRANCH   = 7'b1100011,
    OP_LOAD     = 7'b0000011,
    OP_STORE    = 7'b0100011,
    OP_OP_IMM   = 7'b0010011,
    OP_OP       = 7'b0110011,
    OP_MISC_MEM = 7'b0001111,
    OP_SYSTEM   = 7'b1110011,
    OP_OP_IMM_32 = 7'b0011011,  // RV64I: word immediate operations
    OP_OP_32     = 7'b0111011   // RV64I: word register operations
  } opcode_e;

  //--------------------------------------------------------------------------
  // Funct3 for Branch Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_BEQ  = 3'b000,
    FUNCT3_BNE  = 3'b001,
    FUNCT3_BLT  = 3'b100,
    FUNCT3_BGE  = 3'b101,
    FUNCT3_BLTU = 3'b110,
    FUNCT3_BGEU = 3'b111
  } branch_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for Load Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_LB  = 3'b000,
    FUNCT3_LH  = 3'b001,
    FUNCT3_LW  = 3'b010,
    FUNCT3_LBU = 3'b100,
    FUNCT3_LHU = 3'b101
  } load_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for Store Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_SB = 3'b000,
    FUNCT3_SH = 3'b001,
    FUNCT3_SW = 3'b010
  } store_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for ALU Immediate Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_ADDI  = 3'b000,
    FUNCT3_SLTI  = 3'b010,
    FUNCT3_SLTIU = 3'b011,
    FUNCT3_XORI  = 3'b100,
    FUNCT3_ORI   = 3'b110,
    FUNCT3_ANDI  = 3'b111,
    FUNCT3_SLLI  = 3'b001,
    FUNCT3_SRXI  = 3'b101   // SRL/SRA based on funct7
  } alu_imm_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for ALU Register Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_ADD_SUB = 3'b000,
    FUNCT3_SLL     = 3'b001,
    FUNCT3_SLT     = 3'b010,
    FUNCT3_SLTU    = 3'b011,
    FUNCT3_XOR     = 3'b100,
    FUNCT3_SRX     = 3'b101,  // SRL/SRA based on funct7
    FUNCT3_OR      = 3'b110,
    FUNCT3_AND     = 3'b111
  } alu_reg_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for M Extension
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_MUL    = 3'b000,
    FUNCT3_MULH   = 3'b001,
    FUNCT3_MULHSU = 3'b010,
    FUNCT3_MULHU  = 3'b011,
    FUNCT3_DIV    = 3'b100,
    FUNCT3_DIVU   = 3'b101,
    FUNCT3_REM    = 3'b110,
    FUNCT3_REMU   = 3'b111
  } muldiv_funct3_e;

  //--------------------------------------------------------------------------
  // Funct3 for CSR Instructions
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FUNCT3_PRIV   = 3'b000,  // ECALL, EBREAK, MRET, etc.
    FUNCT3_CSRRW  = 3'b001,
    FUNCT3_CSRRS  = 3'b010,
    FUNCT3_CSRRC  = 3'b011,
    FUNCT3_CSRRWI = 3'b101,
    FUNCT3_CSRRSI = 3'b110,
    FUNCT3_CSRRCI = 3'b111
  } csr_funct3_e;

  //--------------------------------------------------------------------------
  // ALU Operations
  //--------------------------------------------------------------------------
  typedef enum logic [4:0] {
    ALU_ADD    = 5'b00000,
    ALU_SUB    = 5'b00001,
    ALU_SLL    = 5'b00010,
    ALU_SLT    = 5'b00011,
    ALU_SLTU   = 5'b00100,
    ALU_XOR    = 5'b00101,
    ALU_SRL    = 5'b00110,
    ALU_SRA    = 5'b00111,
    ALU_OR     = 5'b01000,
    ALU_AND    = 5'b01001,
    ALU_PASS_B = 5'b01010,  // Pass operand B (for LUI)
    // RV64I word operations (32-bit with sign-extension)
    ALU_ADDW   = 5'b01011,  // Add word
    ALU_SUBW   = 5'b01100,  // Subtract word
    ALU_SLLW   = 5'b01101,  // Shift left logical word
    ALU_SRLW   = 5'b01110,  // Shift right logical word
    ALU_SRAW   = 5'b01111   // Shift right arithmetic word
  } alu_op_e;

  //--------------------------------------------------------------------------
  // MulDiv Operations
  //--------------------------------------------------------------------------
  typedef enum logic [3:0] {
    MD_MUL    = 4'b0000,
    MD_MULH   = 4'b0001,
    MD_MULHSU = 4'b0010,
    MD_MULHU  = 4'b0011,
    MD_DIV    = 4'b0100,
    MD_DIVU   = 4'b0101,
    MD_REM    = 4'b0110,
    MD_REMU   = 4'b0111,
    // RV64M 32-bit operations
    MD_MULW   = 4'b1000,
    MD_DIVW   = 4'b1100,
    MD_DIVUW  = 4'b1101,
    MD_REMW   = 4'b1110,
    MD_REMUW  = 4'b1111
  } muldiv_op_e;

  //--------------------------------------------------------------------------
  // Branch Comparison Operations
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BR_NONE = 3'b000,
    BR_EQ   = 3'b001,
    BR_NE   = 3'b010,
    BR_LT   = 3'b011,
    BR_GE   = 3'b100,
    BR_LTU  = 3'b101,
    BR_GEU  = 3'b110
  } branch_op_e;

  //--------------------------------------------------------------------------
  // Memory Operation Width
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    MEM_BYTE  = 2'b00,
    MEM_HALF  = 2'b01,
    MEM_WORD  = 2'b10,
    MEM_DWORD = 2'b11   // RV64I: doubleword (64-bit)
  } mem_width_e;

  //--------------------------------------------------------------------------
  // Forwarding Mux Select
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    FWD_NONE   = 2'b00,  // No forwarding, use regfile
    FWD_EX_MEM = 2'b01,  // Forward from EX/MEM
    FWD_MEM_WB = 2'b10   // Forward from MEM/WB
  } fwd_sel_e;

  //--------------------------------------------------------------------------
  // CSR Addresses (Minimum Required Set)
  //--------------------------------------------------------------------------
  typedef enum logic [11:0] {
    CSR_MSTATUS   = 12'h300,
    CSR_MIE       = 12'h304,
    CSR_MTVEC     = 12'h305,
    CSR_MEPC      = 12'h341,
    CSR_MCAUSE    = 12'h342,
    CSR_MTVAL     = 12'h343,
    CSR_MIP       = 12'h344,
    CSR_CYCLE     = 12'hC00,
    CSR_CYCLEH    = 12'hC80,
    CSR_INSTRET   = 12'hC02,
    CSR_INSTRETH  = 12'hC82,
    CSR_MVENDORID = 12'hF11,
    CSR_MARCHID   = 12'hF12,
    CSR_MIMPID    = 12'hF13,
    CSR_MHARTID   = 12'hF14
  } csr_addr_e;

  //--------------------------------------------------------------------------
  // Exception Causes (mcause values)
  //--------------------------------------------------------------------------
  typedef enum logic [XLEN-1:0] {
    EXC_INSTR_MISALIGN = 64'd0,
    EXC_INSTR_FAULT    = 64'd1,
    EXC_ILLEGAL_INSTR  = 64'd2,
    EXC_BREAKPOINT     = 64'd3,
    EXC_LOAD_MISALIGN  = 64'd4,
    EXC_LOAD_FAULT     = 64'd5,
    EXC_STORE_MISALIGN = 64'd6,
    EXC_STORE_FAULT    = 64'd7,
    EXC_ECALL_M        = 64'd11
  } exc_cause_e;

  //--------------------------------------------------------------------------
  // Pipeline Stage Bundles
  //--------------------------------------------------------------------------

  // IF/ID Pipeline Register
  typedef struct packed {
    logic [XLEN-1:0] pc;
    logic [ILEN-1:0] instr;
    logic            valid;
    logic            pred_taken;   // Branch prediction
    logic [XLEN-1:0] pred_target;
  } if_id_reg_t;

  // ID/EX Pipeline Register
  typedef struct packed {
    logic [XLEN-1:0]       pc;
    logic [XLEN-1:0]       rs1_data;
    logic [XLEN-1:0]       rs2_data;
    logic [XLEN-1:0]       imm;
    logic [REG_ADDR_W-1:0] rs1_addr;
    logic [REG_ADDR_W-1:0] rs2_addr;
    logic [REG_ADDR_W-1:0] rd_addr;
    alu_op_e               alu_op;
    branch_op_e            branch_op;
    muldiv_op_e            muldiv_op;
    logic                  alu_src;        // 0: rs2, 1: imm
    logic                  mem_read;
    logic                  mem_write;
    mem_width_e            mem_width;
    logic                  mem_unsigned;
    logic                  reg_write;
    logic                  is_branch;
    logic                  is_jal;
    logic                  is_jalr;
    logic                  is_muldiv;
    logic                  is_csr;
    logic [11:0]           csr_addr;
    logic [2:0]            csr_op;
    logic                  is_ecall;
    logic                  is_ebreak;
    logic                  is_mret;
    logic                  is_auipc;
    logic                  illegal_instr;
    logic                  valid;
    logic                  pred_taken;
    logic [XLEN-1:0]       pred_target;
  } id_ex_reg_t;

  // EX/MEM Pipeline Register
  typedef struct packed {
    logic [XLEN-1:0]       pc;
    logic [XLEN-1:0]       alu_result;
    logic [XLEN-1:0]       rs2_data;
    logic [REG_ADDR_W-1:0] rd_addr;
    logic                  mem_read;
    logic                  mem_write;
    mem_width_e            mem_width;
    logic                  mem_unsigned;
    logic                  reg_write;
    logic                  valid;
  } ex_mem_reg_t;

  // MEM/WB Pipeline Register
  typedef struct packed {
    logic [XLEN-1:0]       pc;
    logic [XLEN-1:0]       result;
    logic [REG_ADDR_W-1:0] rd_addr;
    logic                  reg_write;
    logic                  valid;
  } mem_wb_reg_t;

  //--------------------------------------------------------------------------
  // Control Signals Bundle
  //--------------------------------------------------------------------------
  typedef struct packed {
    logic stall_if;
    logic stall_id;
    logic stall_ex;
    logic stall_mem;
    logic flush_if;
    logic flush_id;
    logic flush_ex;
    logic flush_mem;
  } ctrl_signals_t;

endpackage : ironcore_pkg
