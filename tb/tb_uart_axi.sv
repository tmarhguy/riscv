module tb_uart_axi;

    logic clk, rst_n;
    
    // AXI Signals
    logic [31:0] s_axi_awaddr;
    logic [2:0]  s_axi_awprot;
    logic        s_axi_awvalid;
    logic        s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid;
    logic        s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;
    logic [31:0] s_axi_araddr;
    logic [2:0]  s_axi_arprot;
    logic        s_axi_arvalid;
    logic        s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready;
    logic        tx_o, rx_i, irq_o;

    uart_axi dut (
        .clk_i(clk),
        .rst_ni(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .tx_o(tx_o),
        .rx_i(rx_i),
        .irq_o(irq_o)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("uart_axi_test.vcd");
        $dumpvars(0, tb_uart_axi);
        
        rst_n = 0;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        
        #20 rst_n = 1;
        #20;
        
        // Write to DIVISOR (0xC) = 10
        $display("Setting Divisor...");
        s_axi_awaddr = 32'h0C;
        s_axi_awvalid = 1;
        s_axi_wdata = 32'd10;
        s_axi_wvalid = 1;
        s_axi_wstrb = 4'hF;
        s_axi_bready = 1;
        
        wait(s_axi_awready && s_axi_wready);
        #10;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        wait(s_axi_bvalid);
        #10;
        s_axi_bready = 0;
        
        // Write to TX DATA (0x0) = 'A' (0x41)
        $display("Writing 'A' to TX...");
        s_axi_awaddr = 32'h00;
        s_axi_awvalid = 1;
        s_axi_wdata = 32'h41;
        s_axi_wvalid = 1;
        s_axi_bready = 1;
        
        wait(s_axi_awready && s_axi_wready);
        #10;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        wait(s_axi_bvalid);
        #10;
        s_axi_bready = 0;
        
        // Wait for TX to complete
        #2000;
        $display("Test Complete");
        $finish;
    end

endmodule
