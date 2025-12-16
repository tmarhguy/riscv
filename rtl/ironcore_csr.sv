// IronCore CSR Unit - Control and Status Registers
// Implements minimum required CSRs for M-mode operation

import ironcore_pkg::*;
module ironcore_csr (
    input logic clk_i,
    input logic rst_ni,

    // CSR access interface
    input  logic [    11:0] csr_addr_i,
    input  logic            csr_wen_i,
    input  logic [     2:0] csr_op_i,
    input  logic [XLEN-1:0] csr_wdata_i,
    output logic [XLEN-1:0] csr_rdata_o,

    // Trap interface
    input logic            trap_taken_i,
    input logic [XLEN-1:0] trap_pc_i,
    input logic [XLEN-1:0] trap_cause_i,
    input logic [XLEN-1:0] trap_val_i, // Added: Bad address or instruction
    input logic            mret_i,

    // CSR outputs for control
    output logic [XLEN-1:0] mtvec_o,
    output logic [XLEN-1:0] mepc_o
);

  //--------------------------------------------------------------------------
  // CSR Registers
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] mstatus;
  logic [XLEN-1:0] mie;
  logic [XLEN-1:0] mtvec;
  logic [XLEN-1:0] mepc;
  logic [XLEN-1:0] mcause;
  logic [XLEN-1:0] mtval; // Added
  logic [XLEN-1:0] mip;

  // ... (Performance counters unchanged)
  logic [63:0] cycle_cnt;
  logic [63:0] instret_cnt;

  // ... (Constants unchanged)
  localparam logic [XLEN-1:0] MVENDORID = 32'h0;
  localparam logic [XLEN-1:0] MARCHID = 32'h0;
  localparam logic [XLEN-1:0] MIMPID = 32'h0100_0001;
  localparam logic [XLEN-1:0] MHARTID = 32'h0;

  // ... (Bit positions unchanged)
  localparam int MieBit = 3;
  localparam int MpieBit = 7;

  //--------------------------------------------------------------------------
  // CSR Read Logic
  //--------------------------------------------------------------------------
  always_comb begin
    csr_rdata_o = '0;
    case (csr_addr_i)
      CSR_MSTATUS:   csr_rdata_o = mstatus;
      CSR_MIE:       csr_rdata_o = mie;
      CSR_MTVEC:     csr_rdata_o = mtvec;
      CSR_MEPC:      csr_rdata_o = mepc;
      CSR_MCAUSE:    csr_rdata_o = mcause;
      CSR_MTVAL:     csr_rdata_o = mtval; // Added
      CSR_MIP:       csr_rdata_o = mip;
      CSR_CYCLE:     csr_rdata_o = cycle_cnt[31:0];
      CSR_CYCLEH:    csr_rdata_o = cycle_cnt[63:32];
      CSR_INSTRET:   csr_rdata_o = instret_cnt[31:0];
      CSR_INSTRETH:  csr_rdata_o = instret_cnt[63:32];
      CSR_MVENDORID: csr_rdata_o = MVENDORID;
      CSR_MARCHID:   csr_rdata_o = MARCHID;
      CSR_MIMPID:    csr_rdata_o = MIMPID;
      CSR_MHARTID:   csr_rdata_o = MHARTID;
      default:       csr_rdata_o = '0;
    endcase
  end

  // ... (Write data calc unchanged)
  logic [XLEN-1:0] csr_wdata_new;
  always_comb begin
    case (csr_op_i)
      FUNCT3_CSRRW, FUNCT3_CSRRWI: csr_wdata_new = csr_wdata_i;
      FUNCT3_CSRRS, FUNCT3_CSRRSI: csr_wdata_new = csr_rdata_o | csr_wdata_i;
      FUNCT3_CSRRC, FUNCT3_CSRRCI: csr_wdata_new = csr_rdata_o & ~csr_wdata_i;
      default:                     csr_wdata_new = csr_wdata_i;
    endcase
  end

  //--------------------------------------------------------------------------
  // CSR Write Logic
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mstatus <= '0;
      mie     <= '0;
      mtvec   <= '0;
      mepc    <= '0;
      mcause  <= '0;
      mtval   <= '0; // Added
      mip     <= '0;
    end else begin
      // Trap handling
      if (trap_taken_i) begin
        mepc    <= trap_pc_i;
        mcause  <= trap_cause_i;
        mtval   <= trap_val_i; // Added
        // Save MIE to MPIE, clear MIE
        mstatus[MpieBit] <= mstatus[MieBit];
        mstatus[MieBit]  <= 1'b0;
      end  // MRET handling
      else if (mret_i) begin
        // Restore MIE from MPIE, set MPIE to 1
        mstatus[MieBit]  <= mstatus[MpieBit];
        mstatus[MpieBit] <= 1'b1;
      end  // Normal CSR write
      else if (csr_wen_i) begin
        case (csr_addr_i)
          CSR_MSTATUS: mstatus <= csr_wdata_new & 64'h0000_0000_0000_0088;
          CSR_MIE:     mie <= csr_wdata_new;
          CSR_MTVEC:   mtvec <= {csr_wdata_new[XLEN-1:2], 2'b00};
          CSR_MEPC:    mepc <= {csr_wdata_new[XLEN-1:2], 2'b00};
          CSR_MCAUSE:  mcause <= csr_wdata_new;
          CSR_MTVAL:   mtval <= csr_wdata_new; // Added
          CSR_MIP:     mip <= csr_wdata_new;
          default:     ;
        endcase
      end
    end
  end

  // ... (Rest unchanged)
  // ...
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_cnt   <= '0;
      instret_cnt <= '0;
    end else begin
      cycle_cnt <= cycle_cnt + 1'b1;
    end
  end

  assign mtvec_o = mtvec;
  assign mepc_o  = mepc;

// ... (Assertions unchanged)
`ifndef SYNTHESIS
  // mepc should be aligned to 4 bytes
  assert property (@(posedge clk_i) disable iff (!rst_ni) mepc[1:0] == 2'b00)
  else $error("mepc is misaligned: %h", mepc);

  // mtvec should be aligned to 4 bytes (direct mode)
  assert property (@(posedge clk_i) disable iff (!rst_ni) mtvec[1:0] == 2'b00)
  else $error("mtvec is misaligned: %h", mtvec);
`endif

endmodule : ironcore_csr
