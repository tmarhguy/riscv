module wb_to_axi4lite #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // Wishbone Slave Interface
    input  logic                    wb_cyc_i,
    input  logic                    wb_stb_i,
    input  logic                    wb_we_i,
    input  logic [ADDR_WIDTH-1:0]   wb_adr_i,
    input  logic [DATA_WIDTH-1:0]   wb_dat_i,
    input  logic [DATA_WIDTH/8-1:0] wb_sel_i,
    output logic [DATA_WIDTH-1:0]   wb_dat_o,
    output logic                    wb_ack_o,

    // AXI4-Lite Master Interface
    // Write Address Channel
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [2:0]              m_axi_awprot,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,

    // Write Data Channel
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,

    // Write Response Channel
    input  logic [1:0]              m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,

    // Read Address Channel
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [2:0]              m_axi_arprot,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,

    // Read Data Channel
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready
);

    // State machine for transaction handling
    typedef enum logic [1:0] {
        IDLE,
        WRITE_ACCESS,
        READ_ACCESS,
        RESPONSE
    } state_t;

    state_t state, next_state;

    // Internal registers
    logic aw_done, w_done, b_done;
    logic ar_done, r_done;

    // Default PROT value (unprivileged, non-secure, data access)
    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;

    //-------------------------------------------------------------------------
    // FSM Logic
    //-------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state   <= IDLE;
            aw_done <= 1'b0;
            w_done  <= 1'b0;
            b_done  <= 1'b0;
            ar_done <= 1'b0;
            r_done  <= 1'b0;
        end else begin
            state   <= next_state;

            // Track completion of individual AXI handshakes
            if (state == IDLE) begin
                aw_done <= 1'b0;
                w_done  <= 1'b0;
                b_done  <= 1'b0;
                ar_done <= 1'b0;
                r_done  <= 1'b0;
            end else if (state == WRITE_ACCESS) begin
                if (m_axi_awvalid && m_axi_awready) aw_done <= 1'b1;
                if (m_axi_wvalid && m_axi_wready)   w_done  <= 1'b1;
                if (m_axi_bvalid && m_axi_bready)   b_done  <= 1'b1;
            end else if (state == READ_ACCESS) begin
                if (m_axi_arvalid && m_axi_arready) ar_done <= 1'b1;
                if (m_axi_rvalid && m_axi_rready)   r_done  <= 1'b1;
            end
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (wb_cyc_i && wb_stb_i) begin
                    if (wb_we_i) begin
                        next_state = WRITE_ACCESS;
                    end else begin
                        next_state = READ_ACCESS;
                    end
                end
            end

            WRITE_ACCESS: begin
                // Wait for Address Write, Data Write, and Write Response to complete
                // Note: b_done check ensures we received the B response
                if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                    (w_done  || (m_axi_wvalid && m_axi_wready)) &&
                    (b_done  || (m_axi_bvalid && m_axi_bready))) begin
                    next_state = IDLE;
                end
            end

            READ_ACCESS: begin
                // Wait for Address Read and Data Read to complete
                if ((ar_done || (m_axi_arvalid && m_axi_arready)) &&
                    (r_done  || (m_axi_rvalid && m_axi_rready))) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    //-------------------------------------------------------------------------
    // Output Logic
    //-------------------------------------------------------------------------
    
    // Wishbone Outputs
    // Ack is asserted when the full transaction is complete
    always_comb begin
        wb_ack_o = 1'b0;
        if (state == WRITE_ACCESS && next_state == IDLE) begin
            wb_ack_o = 1'b1;
        end else if (state == READ_ACCESS && next_state == IDLE) begin
            wb_ack_o = 1'b1;
        end
    end

    assign wb_dat_o = m_axi_rdata;

    // AXI Write Address Channel
    always_comb begin
        m_axi_awvalid = 1'b0;
        m_axi_awaddr  = wb_adr_i;
        if (state == WRITE_ACCESS && !aw_done) begin
            m_axi_awvalid = 1'b1; 
        end
    end

    // AXI Write Data Channel
    always_comb begin
        m_axi_wvalid = 1'b0;
        m_axi_wdata  = wb_dat_i;
        m_axi_wstrb  = wb_sel_i;
        if (state == WRITE_ACCESS && !w_done) begin
            m_axi_wvalid = 1'b1;
        end
    end

    // AXI Write Response Channel
    // We are always ready to accept response during WRITE_ACCESS
    assign m_axi_bready = (state == WRITE_ACCESS) && !b_done; 

    // AXI Read Address Channel
    always_comb begin
        m_axi_arvalid = 1'b0;
        m_axi_araddr  = wb_adr_i;
        if (state == READ_ACCESS && !ar_done) begin
            m_axi_arvalid = 1'b1;
        end
    end

    // AXI Read Data Channel
    // We are always ready to accept read data during READ_ACCESS
    assign m_axi_rready = (state == READ_ACCESS) && !r_done;

endmodule
