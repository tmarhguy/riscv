// IronCore AXI4-Lite Instruction Memory Bridge
// Converts simple instruction fetch interface to AXI4-Lite master

import ironcore_pkg::*;

module ironcore_axi4lite_imem (
    input logic clk_i,
    input logic rst_ni,

    // Simple instruction fetch interface (from IF stage)
    input  logic            fetch_req_i,
    input  logic [XLEN-1:0] fetch_addr_i,
    output logic [XLEN-1:0] fetch_data_o,
    output logic            fetch_valid_o,
    output logic            fetch_stall_o,

    // AXI4-Lite Master Interface (Read-only)
    output logic            m_axi_arvalid,
    input  logic            m_axi_arready,
    output logic [XLEN-1:0] m_axi_araddr,
    output logic [     2:0] m_axi_arprot,

    input  logic            m_axi_rvalid,
    output logic            m_axi_rready,
    input  logic [XLEN-1:0] m_axi_rdata,
    input  logic [     1:0] m_axi_rresp
);

  //--------------------------------------------------------------------------
  // State Machine
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    ADDR   = 2'b01,
    DATA   = 2'b10
  } state_e;

  state_e state_q, state_d;

  //--------------------------------------------------------------------------
  // Internal Signals
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] addr_q;
  logic [XLEN-1:0] data_q;
  logic            error_q;

  //--------------------------------------------------------------------------
  // State Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      addr_q  <= '0;
      data_q  <= '0;
      error_q <= '0;
    end else begin
      state_q <= state_d;
      
      // Latch address when request accepted
      if (state_q == IDLE && fetch_req_i) begin
        addr_q <= fetch_addr_i;
      end
      
      // Latch data when response received
      if (state_q == DATA && m_axi_rvalid) begin
        data_q  <= m_axi_rdata;
        error_q <= (m_axi_rresp != 2'b00);  // OKAY = 00, others are errors
      end
    end
  end

  //--------------------------------------------------------------------------
  // Next State Logic
  //--------------------------------------------------------------------------
  always_comb begin
    state_d = state_q;

    case (state_q)
      IDLE: begin
        if (fetch_req_i) begin
          state_d = ADDR;
        end
      end

      ADDR: begin
        if (m_axi_arready) begin
          state_d = DATA;
        end
      end

      DATA: begin
        if (m_axi_rvalid) begin
          state_d = IDLE;
        end
      end

      default: state_d = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // AXI4-Lite Address Channel
  //--------------------------------------------------------------------------
  assign m_axi_arvalid = (state_q == ADDR);
  assign m_axi_araddr  = addr_q;
  assign m_axi_arprot  = 3'b000;  // Unprivileged, secure, data access

  //--------------------------------------------------------------------------
  // AXI4-Lite Read Data Channel
  //--------------------------------------------------------------------------
  assign m_axi_rready = (state_q == DATA);

  //--------------------------------------------------------------------------
  // Output Interface
  //--------------------------------------------------------------------------
  assign fetch_data_o  = data_q;
  assign fetch_valid_o = (state_q == IDLE) && (state_d == IDLE) && !error_q;
  assign fetch_stall_o = (state_q != IDLE) || fetch_req_i;

  //--------------------------------------------------------------------------
  // Assertions
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  // Address must be word-aligned
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    fetch_req_i |-> fetch_addr_i[1:0] == 2'b00
  ) else $error("Unaligned instruction fetch address: %h", fetch_addr_i);

  // AXI4-Lite protocol: ARVALID must remain asserted until ARREADY
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_arvalid && !m_axi_arready |=> m_axi_arvalid
  ) else $error("ARVALID deasserted before ARREADY");

  // AXI4-Lite protocol: RREADY must remain asserted until RVALID
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_rready && !m_axi_rvalid |=> m_axi_rready
  ) else $error("RREADY deasserted before RVALID");
`endif

endmodule : ironcore_axi4lite_imem
