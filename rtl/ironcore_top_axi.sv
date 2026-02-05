// IronCore Top-Level Module with AXI4-Lite Interfaces
// Alternative top module using AXI4-Lite instead of Wishbone

import ironcore_pkg::*;

module ironcore_top_axi #(
    parameter logic [XLEN-1:0] RESET_PC = 64'h0000_0000
) (
    input logic clk_i,
    input logic rst_ni,

    // Instruction Memory AXI4-Lite Master Interface
    output logic            m_axi_imem_arvalid,
    input  logic            m_axi_imem_arready,
    output logic [XLEN-1:0] m_axi_imem_araddr,
    output logic [     2:0] m_axi_imem_arprot,
    input  logic            m_axi_imem_rvalid,
    output logic            m_axi_imem_rready,
    input  logic [XLEN-1:0] m_axi_imem_rdata,
    input  logic [     1:0] m_axi_imem_rresp,

    // Data Memory AXI4-Lite Master Interface
    output logic            m_axi_dmem_awvalid,
    input  logic            m_axi_dmem_awready,
    output logic [XLEN-1:0] m_axi_dmem_awaddr,
    output logic [     2:0] m_axi_dmem_awprot,
    output logic            m_axi_dmem_wvalid,
    input  logic            m_axi_dmem_wready,
    output logic [XLEN-1:0] m_axi_dmem_wdata,
    output logic [     3:0] m_axi_dmem_wstrb,
    input  logic            m_axi_dmem_bvalid,
    output logic            m_axi_dmem_bready,
    input  logic [     1:0] m_axi_dmem_bresp,
    output logic            m_axi_dmem_arvalid,
    input  logic            m_axi_dmem_arready,
    output logic [XLEN-1:0] m_axi_dmem_araddr,
    output logic [     2:0] m_axi_dmem_arprot,
    input  logic            m_axi_dmem_rvalid,
    output logic            m_axi_dmem_rready,
    input  logic [XLEN-1:0] m_axi_dmem_rdata,
    input  logic [     1:0] m_axi_dmem_rresp
);

  //--------------------------------------------------------------------------
  // Internal Wishbone Signals (from existing core)
  //--------------------------------------------------------------------------
  logic            iwb_cyc;
  logic            iwb_stb;
  logic [XLEN-1:0] iwb_adr;
  logic [XLEN-1:0] iwb_dat;
  logic            iwb_ack;

  logic            dwb_cyc;
  logic            dwb_stb;
  logic            dwb_we;
  logic [XLEN-1:0] dwb_adr;
  logic [XLEN-1:0] dwb_dat_o;
  logic [     3:0] dwb_sel;
  logic [XLEN-1:0] dwb_dat_i;
  logic            dwb_ack;

  //--------------------------------------------------------------------------
  // Instantiate Original IronCore with Wishbone
  //--------------------------------------------------------------------------
  ironcore_top #(
      .RESET_PC(RESET_PC)
  ) u_core (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .iwb_cyc_o (iwb_cyc),
      .iwb_stb_o (iwb_stb),
      .iwb_adr_o (iwb_adr),
      .iwb_dat_i (iwb_dat),
      .iwb_ack_i (iwb_ack),
      .dwb_cyc_o (dwb_cyc),
      .dwb_stb_o (dwb_stb),
      .dwb_we_o  (dwb_we),
      .dwb_adr_o (dwb_adr),
      .dwb_dat_o (dwb_dat_o),
      .dwb_sel_o (dwb_sel),
      .dwb_dat_i (dwb_dat_i),
      .dwb_ack_i (dwb_ack)
  );

  //--------------------------------------------------------------------------
  // Wishbone to AXI4-Lite Bridge - Instruction Memory
  //--------------------------------------------------------------------------
  wb_to_axi4lite #(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32)
  ) u_iwb_to_axi (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      // Wishbone slave
      .wb_cyc_i(iwb_cyc),
      .wb_stb_i(iwb_stb),
      .wb_we_i (1'b0),  // Read-only
      .wb_adr_i(iwb_adr),
      .wb_dat_i('0),
      .wb_sel_i(4'hF),
      .wb_dat_o(iwb_dat),
      .wb_ack_o(iwb_ack),
      // AXI4-Lite master
      .m_axi_awvalid(),  // Unused for read-only
      .m_axi_awready(1'b0),
      .m_axi_awaddr (),
      .m_axi_awprot (),
      .m_axi_wvalid (),
      .m_axi_wready (1'b0),
      .m_axi_wdata  (),
      .m_axi_wstrb  (),
      .m_axi_bvalid (1'b0),
      .m_axi_bready (),
      .m_axi_bresp  (2'b00),
      .m_axi_arvalid(m_axi_imem_arvalid),
      .m_axi_arready(m_axi_imem_arready),
      .m_axi_araddr (m_axi_imem_araddr),
      .m_axi_arprot (m_axi_imem_arprot),
      .m_axi_rvalid (m_axi_imem_rvalid),
      .m_axi_rready (m_axi_imem_rready),
      .m_axi_rdata  (m_axi_imem_rdata),
      .m_axi_rresp  (m_axi_imem_rresp)
  );

  //--------------------------------------------------------------------------
  // Wishbone to AXI4-Lite Bridge - Data Memory
  //--------------------------------------------------------------------------
  wb_to_axi4lite #(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32)
  ) u_dwb_to_axi (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      // Wishbone slave
      .wb_cyc_i(dwb_cyc),
      .wb_stb_i(dwb_stb),
      .wb_we_i (dwb_we),
      .wb_adr_i(dwb_adr),
      .wb_dat_i(dwb_dat_o),
      .wb_sel_i(dwb_sel),
      .wb_dat_o(dwb_dat_i),
      .wb_ack_o(dwb_ack),
      // AXI4-Lite master
      .m_axi_awvalid(m_axi_dmem_awvalid),
      .m_axi_awready(m_axi_dmem_awready),
      .m_axi_awaddr (m_axi_dmem_awaddr),
      .m_axi_awprot (m_axi_dmem_awprot),
      .m_axi_wvalid (m_axi_dmem_wvalid),
      .m_axi_wready (m_axi_dmem_wready),
      .m_axi_wdata  (m_axi_dmem_wdata),
      .m_axi_wstrb  (m_axi_dmem_wstrb),
      .m_axi_bvalid (m_axi_dmem_bvalid),
      .m_axi_bready (m_axi_dmem_bready),
      .m_axi_bresp  (m_axi_dmem_bresp),
      .m_axi_arvalid(m_axi_dmem_arvalid),
      .m_axi_arready(m_axi_dmem_arready),
      .m_axi_araddr (m_axi_dmem_araddr),
      .m_axi_arprot (m_axi_dmem_arprot),
      .m_axi_rvalid (m_axi_dmem_rvalid),
      .m_axi_rready (m_axi_dmem_rready),
      .m_axi_rdata  (m_axi_dmem_rdata),
      .m_axi_rresp  (m_axi_dmem_rresp)
  );

endmodule : ironcore_top_axi
