module tb_wb_to_axi4lite;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Wishbone Signals
    logic wb_cyc;
    logic wb_stb;
    logic wb_we;
    logic [ADDR_WIDTH-1:0] wb_adr;
    logic [DATA_WIDTH-1:0] wb_dat_i;
    logic [DATA_WIDTH/8-1:0] wb_sel;
    logic [DATA_WIDTH-1:0] wb_dat_o;
    logic wb_ack;

    // AXI4-Lite Signals
    logic [ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [2:0] m_axi_awprot;
    logic m_axi_awvalid;
    logic m_axi_awready;
    logic [DATA_WIDTH-1:0] m_axi_wdata;
    logic [DATA_WIDTH/8-1:0] m_axi_wstrb;
    logic m_axi_wvalid;
    logic m_axi_wready;
    logic [1:0] m_axi_bresp;
    logic m_axi_bvalid;
    logic m_axi_bready;
    logic [ADDR_WIDTH-1:0] m_axi_araddr;
    logic [2:0] m_axi_arprot;
    logic m_axi_arvalid;
    logic m_axi_arready;
    logic [DATA_WIDTH-1:0] m_axi_rdata;
    logic [1:0] m_axi_rresp;
    logic m_axi_rvalid;
    logic m_axi_rready;

    // DUT Instantiation
    wb_to_axi4lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_ni(rst_n),
        .wb_cyc_i(wb_cyc),
        .wb_stb_i(wb_stb),
        .wb_we_i(wb_we),
        .wb_adr_i(wb_adr),
        .wb_dat_i(wb_dat_i),
        .wb_sel_i(wb_sel),
        .wb_dat_o(wb_dat_o),
        .wb_ack_o(wb_ack),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        $dumpfile("wb_to_axi_test.vcd");
        $dumpvars(0, tb_wb_to_axi4lite);

        // Initialize signals
        rst_n = 0;
        wb_cyc = 0;
        wb_stb = 0;
        wb_we = 0;
        wb_adr = 0;
        wb_dat_i = 0;
        wb_sel = 0;
        
        // AXI Slave Model (Mock)
        m_axi_awready = 0;
        m_axi_wready = 0;
        m_axi_bvalid = 0;
        m_axi_bresp = 0;
        m_axi_arready = 0;
        m_axi_rvalid = 0;
        m_axi_rdata = 0;
        m_axi_rresp = 0;

        // Reset
        #20 rst_n = 1;
        #20;

        // Test 1: Write Transaction
        $display("Starting Write Transaction Test...");
        wb_adr = 32'h1000;
        wb_dat_i = 32'hDEADBEEF;
        wb_sel = 4'hF;
        wb_we = 1;
        wb_cyc = 1;
        wb_stb = 1;

        // Wait for AWVALID and WVALID
        wait(m_axi_awvalid && m_axi_wvalid);
        #5; 
        // Respond with READY
        m_axi_awready = 1;
        m_axi_wready = 1;
        #10;
        m_axi_awready = 0;
        m_axi_wready = 0;

        // Respond with BVALID
        #10;
        m_axi_bvalid = 1;
        
        // Wait for ACK while holding valid
        wait(wb_ack);
        
        // Handshake complete
        m_axi_bvalid = 0;
        wb_cyc = 0;
        wb_stb = 0;
        wb_we = 0;
        #20;
        $display("Write Transaction Complete.");

        // Test 2: Read Transaction
        $display("Starting Read Transaction Test...");
        wb_adr = 32'h2000;
        wb_we = 0;
        wb_cyc = 1;
        wb_stb = 1;

        // Wait for ARVALID
        wait(m_axi_arvalid);
        #5;
        // Respond with READY
        m_axi_arready = 1;
        #10;
        m_axi_arready = 0;

        // Respond with RVALID and DATA
        #10;
        m_axi_rvalid = 1;
        m_axi_rdata = 32'hCAFEBABE;
        
        // Wait for ACK
        wait(wb_ack);
        if (wb_dat_o !== 32'hCAFEBABE) $error("Read Data Mismatch! Expected CAFEBABE, got %h", wb_dat_o);
        
        m_axi_rvalid = 0;
        wb_cyc = 0;
        wb_stb = 0;
        #20;
        $display("Read Transaction Complete.");

        $finish;
    end

endmodule
