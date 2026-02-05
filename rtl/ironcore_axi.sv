module ironcore_axi #(
    parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Instruction AXI4-Lite Interface
    output logic [31:0] m_axi_instr_awaddr,
    output logic [2:0]  m_axi_instr_awprot,
    output logic        m_axi_instr_awvalid,
    input  logic        m_axi_instr_awready,
    output logic [31:0] m_axi_instr_wdata,
    output logic [3:0]  m_axi_instr_wstrb,
    output logic        m_axi_instr_wvalid,
    input  logic        m_axi_instr_wready,
    input  logic [1:0]  m_axi_instr_bresp,
    input  logic        m_axi_instr_bvalid,
    output logic        m_axi_instr_bready,
    output logic [31:0] m_axi_instr_araddr,
    output logic [2:0]  m_axi_instr_arprot,
    output logic        m_axi_instr_arvalid,
    input  logic        m_axi_instr_arready,
    input  logic [31:0] m_axi_instr_rdata,
    input  logic [1:0]  m_axi_instr_rresp,
    input  logic        m_axi_instr_rvalid,
    output logic        m_axi_instr_rready,

    // Data AXI4-Lite Interface
    output logic [31:0] m_axi_data_awaddr,
    output logic [2:0]  m_axi_data_awprot,
    output logic        m_axi_data_awvalid,
    input  logic        m_axi_data_awready,
    output logic [31:0] m_axi_data_wdata,
    output logic [3:0]  m_axi_data_wstrb,
    output logic        m_axi_data_wvalid,
    input  logic        m_axi_data_wready,
    input  logic [1:0]  m_axi_data_bresp,
    input  logic        m_axi_data_bvalid,
    output logic        m_axi_data_bready,
    output logic [31:0] m_axi_data_araddr,
    output logic [2:0]  m_axi_data_arprot,
    output logic        m_axi_data_arvalid,
    input  logic        m_axi_data_arready,
    input  logic [31:0] m_axi_data_rdata,
    input  logic [1:0]  m_axi_data_rresp,
    input  logic        m_axi_data_rvalid,
    output logic        m_axi_data_rready
);

    // Internal Wishbone Signals
    logic        iwb_cyc;
    logic        iwb_stb;
    logic [31:0] iwb_adr;
    logic [31:0] iwb_dat_i;
    logic        iwb_ack;

    logic        dwb_cyc;
    logic        dwb_stb;
    logic        dwb_we;
    logic [31:0] dwb_adr;
    logic [31:0] dwb_dat_o;
    logic [3:0]  dwb_sel;
    logic [31:0] dwb_dat_i;
    logic        dwb_ack;

    // Instantiate IronCore Top (Wishbone)
    ironcore_top #(
        .RESET_PC(RESET_PC)
    ) u_core (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),

        // Instruction Bus
        .iwb_cyc_o(iwb_cyc),
        .iwb_stb_o(iwb_stb),
        .iwb_adr_o(iwb_adr),
        .iwb_dat_i(iwb_dat_i),
        .iwb_ack_i(iwb_ack),

        // Data Bus
        .dwb_cyc_o(dwb_cyc),
        .dwb_stb_o(dwb_stb),
        .dwb_we_o (dwb_we),
        .dwb_adr_o(dwb_adr),
        .dwb_dat_o(dwb_dat_o),
        .dwb_sel_o(dwb_sel),
        .dwb_dat_i(dwb_dat_i),
        .dwb_ack_i(dwb_ack)
    );

    // Instruction Bus Bridge
    // Note: Instructions are read-only, so we tie off write inputs/outputs effectively?
    // Actually, the bridge handles it. IronCore never asserts iwb_we, so it will be a READ.
    wb_to_axi4lite #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32)
    ) u_bridge_instr (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .wb_cyc_i    (iwb_cyc),
        .wb_stb_i    (iwb_stb),
        .wb_we_i     (1'b0),      // Instruction fetch is always read
        .wb_adr_i    (iwb_adr),
        .wb_dat_i    (32'h0),     // No write data
        .wb_sel_i    (4'hF),      // Full word select
        .wb_dat_o    (iwb_dat_i),
        .wb_ack_o    (iwb_ack),

        .m_axi_awaddr (m_axi_instr_awaddr),
        .m_axi_awprot (m_axi_instr_awprot),
        .m_axi_awvalid(m_axi_instr_awvalid),
        .m_axi_awready(m_axi_instr_awready),
        .m_axi_wdata  (m_axi_instr_wdata),
        .m_axi_wstrb  (m_axi_instr_wstrb),
        .m_axi_wvalid (m_axi_instr_wvalid),
        .m_axi_wready (m_axi_instr_wready),
        .m_axi_bresp  (m_axi_instr_bresp),
        .m_axi_bvalid (m_axi_instr_bvalid),
        .m_axi_bready (m_axi_instr_bready),
        .m_axi_araddr (m_axi_instr_araddr),
        .m_axi_arprot (m_axi_instr_arprot),
        .m_axi_arvalid(m_axi_instr_arvalid),
        .m_axi_arready(m_axi_instr_arready),
        .m_axi_rdata  (m_axi_instr_rdata),
        .m_axi_rresp  (m_axi_instr_rresp),
        .m_axi_rvalid (m_axi_instr_rvalid),
        .m_axi_rready (m_axi_instr_rready)
    );

    // Data Bus Bridge
    wb_to_axi4lite #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32)
    ) u_bridge_data (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .wb_cyc_i    (dwb_cyc),
        .wb_stb_i    (dwb_stb),
        .wb_we_i     (dwb_we),
        .wb_adr_i    (dwb_adr),
        .wb_dat_i    (dwb_dat_o),
        .wb_sel_i    (dwb_sel),
        .wb_dat_o    (dwb_dat_i),
        .wb_ack_o    (dwb_ack),

        .m_axi_awaddr (m_axi_data_awaddr),
        .m_axi_awprot (m_axi_data_awprot),
        .m_axi_awvalid(m_axi_data_awvalid),
        .m_axi_awready(m_axi_data_awready),
        .m_axi_wdata  (m_axi_data_wdata),
        .m_axi_wstrb  (m_axi_data_wstrb),
        .m_axi_wvalid (m_axi_data_wvalid),
        .m_axi_wready (m_axi_data_wready),
        .m_axi_bresp  (m_axi_data_bresp),
        .m_axi_bvalid (m_axi_data_bvalid),
        .m_axi_bready (m_axi_data_bready),
        .m_axi_araddr (m_axi_data_araddr),
        .m_axi_arprot (m_axi_data_arprot),
        .m_axi_arvalid(m_axi_data_arvalid),
        .m_axi_arready(m_axi_data_arready),
        .m_axi_rdata  (m_axi_data_rdata),
        .m_axi_rresp  (m_axi_data_rresp),
        .m_axi_rvalid (m_axi_data_rvalid),
        .m_axi_rready (m_axi_data_rready)
    );

endmodule
