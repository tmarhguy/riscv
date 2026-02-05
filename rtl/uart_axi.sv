module uart_axi #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // AXI4-Lite Slave Interface
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]              s_axi_awprot,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]              s_axi_arprot,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // UART Signals
    output logic                    tx_o,
    input  logic                    rx_i,
    output logic                    irq_o
);

    // Register Map
    // 0x0: DATA (R/W) - Read for RX, Write for TX
    // 0x4: STATUS (RO) - [0] TX Full, [1] RX Empty
    // 0x8: CONTROL (RW) - [0] Enable, [1] IRQ Enable
    // 0xC: DIVISOR (RW) - Clock divisor for baud rate

    logic [31:0] reg_data, reg_status, reg_control, reg_divisor;
    
    // Internal Signals
    logic [7:0]  tx_data;
    logic        tx_wr;
    logic        tx_busy;
    
    logic [7:0]  rx_data;
    logic        rx_rd;
    logic        rx_valid;
    
    // AXI4-Lite State Machine
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ
    } state_t;

    state_t state;
    
    // UART Core logic would go here, simplified for this example
    // We will implement a very basic bit-banger style for compact code or instantiate proper blocks if available.
    // For this task, I'll write a compact UART TX/RX core inside logic blocks.

    //-------------------------------------------------------------------------
    // AXI4-Lite Slave Logic
    //-------------------------------------------------------------------------
    logic aw_en;
    logic addr_done;

    // Handshake Management
    assign s_axi_awready = (state == IDLE) || (state == WRITE && !addr_done);
    assign s_axi_wready  = (state == WRITE);
    assign s_axi_arready = (state == IDLE);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= IDLE;
            s_axi_bvalid <= 0;
            s_axi_rvalid <= 0;
            reg_control <= 0;
            reg_divisor <= 32'd100; // Default divisor
            tx_wr <= 0;
            rx_rd <= 0;
        end else begin
            tx_wr <= 0;
            rx_rd <= 0;

            case (state)
                IDLE: begin
                    if (s_axi_awvalid) begin
                        state <= WRITE;
                        addr_done <= 0;
                    end else if (s_axi_arvalid) begin
                        state <= READ;
                        s_axi_arready <= 1; // Pulse ready
                    end
                end

                WRITE: begin
                    if (s_axi_awvalid && s_axi_awready) addr_done <= 1;
                    
                    if (s_axi_wvalid && s_axi_wready) begin
                        state <= IDLE;
                        s_axi_bvalid <= 1;
                        s_axi_bresp <= 0; // OKAY
                        
                        // Register Write Logic
                        case (s_axi_awaddr[3:0])
                            4'h0: begin // DATA
                                tx_data <= s_axi_wdata[7:0];
                                tx_wr   <= 1;
                            end
                            4'h4: ; // STATUS is RO
                            4'h8: reg_control <= s_axi_wdata;
                            4'hC: reg_divisor <= s_axi_wdata;
                        endcase
                    end
                end

                READ: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        state <= IDLE;
                        s_axi_rvalid <= 0;
                    end else begin
                         s_axi_rvalid <= 1;
                         s_axi_rresp <= 0; // OKAY
                         
                         case (s_axi_araddr[3:0])
                            4'h0: begin 
                                s_axi_rdata <= {24'b0, rx_data};
                                rx_rd <= 1; // Pop RX FIFO
                            end
                            4'h4: s_axi_rdata <= {30'b0, !rx_valid, tx_busy}; // Empty, Full
                            4'h8: s_axi_rdata <= reg_control;
                            4'hC: s_axi_rdata <= reg_divisor;
                            default: s_axi_rdata <= 0;
                         endcase
                    end
                end
            endcase

            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
        end
    end

    //-------------------------------------------------------------------------
    // UART Transmitter (Simple)
    //-------------------------------------------------------------------------
    logic [31:0] tx_cnt;
    logic [3:0]  tx_bit_idx;
    logic [9:0]  tx_shift; // Start + 8 data + Stop

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_o <= 1;
            tx_busy <= 0;
            tx_cnt <= 0;
        end else begin
            if (tx_wr && !tx_busy) begin
                tx_busy <= 1;
                tx_shift <= {1'b1, tx_data, 1'b0}; // Stop, Data, Start
                tx_bit_idx <= 0;
                tx_cnt <= 0;
            end else if (tx_busy) begin
                if (tx_cnt >= reg_divisor) begin
                    tx_cnt <= 0;
                    if (tx_bit_idx == 9) begin
                        tx_busy <= 0;
                        tx_o <= 1;
                    end else begin
                        tx_o <= tx_shift[tx_bit_idx];
                        tx_bit_idx <= tx_bit_idx + 1;
                    end
                end else begin
                    tx_cnt <= tx_cnt + 1;
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // UART Receiver (Simple Stub for now)
    //-------------------------------------------------------------------------
    // For this iteration, we focus on TX. RX stubbed.
    assign rx_data = 8'h00;
    assign rx_valid = 0;
    
    assign irq_o = 0;

endmodule
