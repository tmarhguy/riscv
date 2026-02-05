// IronCore AXI4-Lite Data Memory Bridge
// Converts load/store interface to AXI4-Lite master (read/write)

import ironcore_pkg::*;

module ironcore_axi4lite_dmem (
    input logic clk_i,
    input logic rst_ni,

    // Load/Store Interface (from MEM stage)
    input  logic            mem_req_i,
    input  logic            mem_we_i,
    input  logic [XLEN-1:0] mem_addr_i,
    input  logic [XLEN-1:0] mem_wdata_i,
    input  logic [     3:0] mem_be_i,       // Byte enables
    output logic [XLEN-1:0] mem_rdata_o,
    output logic            mem_valid_o,
    output logic            mem_stall_o,
    output logic            mem_error_o,

    // AXI4-Lite Master Interface
    // Write Address Channel
    output logic            m_axi_awvalid,
    input  logic            m_axi_awready,
    output logic [XLEN-1:0] m_axi_awaddr,
    output logic [     2:0] m_axi_awprot,

    // Write Data Channel
    output logic            m_axi_wvalid,
    input  logic            m_axi_wready,
    output logic [XLEN-1:0] m_axi_wdata,
    output logic [     3:0] m_axi_wstrb,

    // Write Response Channel
    input  logic            m_axi_bvalid,
    output logic            m_axi_bready,
    input  logic [     1:0] m_axi_bresp,

    // Read Address Channel
    output logic            m_axi_arvalid,
    input  logic            m_axi_arready,
    output logic [XLEN-1:0] m_axi_araddr,
    output logic [     2:0] m_axi_arprot,

    // Read Data Channel
    input  logic            m_axi_rvalid,
    output logic            m_axi_rready,
    input  logic [XLEN-1:0] m_axi_rdata,
    input  logic [     1:0] m_axi_rresp
);

  //--------------------------------------------------------------------------
  // State Machine
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IDLE       = 3'b000,
    WRITE_ADDR = 3'b001,
    WRITE_DATA = 3'b010,
    WRITE_RESP = 3'b011,
    READ_ADDR  = 3'b100,
    READ_DATA  = 3'b101
  } state_e;

  state_e state_q, state_d;

  //--------------------------------------------------------------------------
  // Internal Registers
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] addr_q;
  logic [XLEN-1:0] wdata_q;
  logic [     3:0] wstrb_q;
  logic [XLEN-1:0] rdata_q;
  logic            error_q;
  logic            is_write_q;

  //--------------------------------------------------------------------------
  // State Register
  //--------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q    <= IDLE;
      addr_q     <= '0;
      wdata_q    <= '0;
      wstrb_q    <= '0;
      rdata_q    <= '0;
      error_q    <= '0;
      is_write_q <= '0;
    end else begin
      state_q <= state_d;

      // Latch request when accepted
      if (state_q == IDLE && mem_req_i) begin
        addr_q     <= mem_addr_i;
        wdata_q    <= mem_wdata_i;
        wstrb_q    <= mem_be_i;
        is_write_q <= mem_we_i;
      end

      // Latch read data
      if (state_q == READ_DATA && m_axi_rvalid) begin
        rdata_q <= m_axi_rdata;
        error_q <= (m_axi_rresp != 2'b00);
      end

      // Latch write response
      if (state_q == WRITE_RESP && m_axi_bvalid) begin
        error_q <= (m_axi_bresp != 2'b00);
      end

      // Clear error on new request
      if (state_q == IDLE && mem_req_i) begin
        error_q <= '0;
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
        if (mem_req_i) begin
          if (mem_we_i) begin
            state_d = WRITE_ADDR;
          end else begin
            state_d = READ_ADDR;
          end
        end
      end

      WRITE_ADDR: begin
        if (m_axi_awready) begin
          state_d = WRITE_DATA;
        end
      end

      WRITE_DATA: begin
        if (m_axi_wready) begin
          state_d = WRITE_RESP;
        end
      end

      WRITE_RESP: begin
        if (m_axi_bvalid) begin
          state_d = IDLE;
        end
      end

      READ_ADDR: begin
        if (m_axi_arready) begin
          state_d = READ_DATA;
        end
      end

      READ_DATA: begin
        if (m_axi_rvalid) begin
          state_d = IDLE;
        end
      end

      default: state_d = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // AXI4-Lite Write Address Channel
  //--------------------------------------------------------------------------
  assign m_axi_awvalid = (state_q == WRITE_ADDR);
  assign m_axi_awaddr  = addr_q;
  assign m_axi_awprot  = 3'b000;  // Unprivileged, secure, data access

  //--------------------------------------------------------------------------
  // AXI4-Lite Write Data Channel
  //--------------------------------------------------------------------------
  assign m_axi_wvalid = (state_q == WRITE_DATA);
  assign m_axi_wdata  = wdata_q;
  assign m_axi_wstrb  = wstrb_q;

  //--------------------------------------------------------------------------
  // AXI4-Lite Write Response Channel
  //--------------------------------------------------------------------------
  assign m_axi_bready = (state_q == WRITE_RESP);

  //--------------------------------------------------------------------------
  // AXI4-Lite Read Address Channel
  //--------------------------------------------------------------------------
  assign m_axi_arvalid = (state_q == READ_ADDR);
  assign m_axi_araddr  = addr_q;
  assign m_axi_arprot  = 3'b000;  // Unprivileged, secure, data access

  //--------------------------------------------------------------------------
  // AXI4-Lite Read Data Channel
  //--------------------------------------------------------------------------
  assign m_axi_rready = (state_q == READ_DATA);

  //--------------------------------------------------------------------------
  // Output Interface
  //--------------------------------------------------------------------------
  assign mem_rdata_o = rdata_q;
  assign mem_valid_o = (state_q == IDLE) && (state_d == IDLE);
  assign mem_stall_o = (state_q != IDLE) || mem_req_i;
  assign mem_error_o = error_q;

  //--------------------------------------------------------------------------
  // Assertions
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  // No simultaneous read and write
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    !(m_axi_awvalid && m_axi_arvalid)
  ) else $error("Simultaneous AXI read and write");

  // Write strobe must be non-zero for writes
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (state_q == IDLE && mem_req_i && mem_we_i) |-> (mem_be_i != 4'b0000)
  ) else $error("Write with zero byte enables");

  // AXI4-Lite protocol: AWVALID stable until AWREADY
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_awvalid && !m_axi_awready |=> m_axi_awvalid
  ) else $error("AWVALID deasserted before AWREADY");

  // AXI4-Lite protocol: WVALID stable until WREADY
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_wvalid && !m_axi_wready |=> m_axi_wvalid
  ) else $error("WVALID deasserted before WREADY");

  // AXI4-Lite protocol: BREADY stable until BVALID
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_bready && !m_axi_bvalid |=> m_axi_bready
  ) else $error("BREADY deasserted before BVALID");

  // AXI4-Lite protocol: ARVALID stable until ARREADY
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_arvalid && !m_axi_arready |=> m_axi_arvalid
  ) else $error("ARVALID deasserted before ARREADY");

  // AXI4-Lite protocol: RREADY stable until RVALID
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    m_axi_rready && !m_axi_rvalid |=> m_axi_rready
  ) else $error("RREADY deasserted before RVALID");
`endif

endmodule : ironcore_axi4lite_dmem
