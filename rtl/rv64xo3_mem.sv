// riscv64xO3 MEM Stage - Memory Access
// Handles load/store operations via Wishbone interface

import rv64xo3_pkg::*;
module rv64xo3_mem (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register input
    input rv64xo3_pkg::ex_mem_reg_t ex_mem_reg_i,

    // Data Wishbone interface
    output logic            dwb_cyc_o,
    output logic            dwb_stb_o,
    output logic            dwb_we_o,
    output logic [XLEN-1:0] dwb_adr_o,
    output logic [XLEN-1:0] dwb_dat_o,
    output logic [(XLEN/8)-1:0] dwb_sel_o,
    input  logic [XLEN-1:0] dwb_dat_i,
    input  logic            dwb_ack_i,

    // Outputs
    output logic [XLEN-1:0] mem_rdata_o,
    output logic            mem_stall_o,

    // Exception outputs
    output logic            mem_exc_valid_o,
    output logic [XLEN-1:0] mem_exc_cause_o
);

  //--------------------------------------------------------------------------
  // FSM for Memory Access
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    ACCESS,
    WAIT_ACK
  } mem_state_e;

  mem_state_e state, state_next;

  //--------------------------------------------------------------------------
  // Access splitting for (possibly misaligned) loads/stores
  //--------------------------------------------------------------------------
  // The bus moves one 4B-aligned word per transaction, carrying up to 8
  // bytes (sel-masked). An access [A, A+S) with S in {1,2,4,8} therefore
  // needs at most two transactions: the 8B window [W*4, W*4+8) around the
  // first word plus, if the tail spills past it, one more at the next word.
  // (Stride-4 windows of width 8 always cover an <=8B access with first+last.)
  logic [3:0] acc_bytes;  // access size in bytes
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE:  acc_bytes = 4'd1;
      MEM_HALF:  acc_bytes = 4'd2;
      MEM_WORD:  acc_bytes = 4'd4;
      MEM_DWORD: acc_bytes = 4'd8;
      default:   acc_bytes = 4'd4;
    endcase
  end

  logic [1:0] addr_off;  // byte offset of A inside its word
  assign addr_off = ex_mem_reg_i.alu_result[1:0];

  // Bytes served by the first transaction: everything up to the end of the
  // first 8B window. Remainder (maybe zero) goes in the second transaction.
  logic [3:0] first_nbytes;
  assign first_nbytes = ((4'd8 - {2'b00, addr_off}) < acc_bytes) ?
                        (4'd8 - {2'b00, addr_off}) : acc_bytes;
  logic [3:0] second_nbytes;
  assign second_nbytes = acc_bytes - first_nbytes;

  // Store data, low-aligned (access byte 0 at [7:0])
  logic [XLEN-1:0] store_lo;
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE:  store_lo = {56'b0, ex_mem_reg_i.rs2_data[7:0]};
      MEM_HALF:  store_lo = {48'b0, ex_mem_reg_i.rs2_data[15:0]};
      MEM_WORD:  store_lo = {32'b0, ex_mem_reg_i.rs2_data[31:0]};
      MEM_DWORD: store_lo = ex_mem_reg_i.rs2_data;
      default:   store_lo = ex_mem_reg_i.rs2_data;
    endcase
  end

  // Per-transaction select/data. Transaction 0 starts at bit addr_off of
  // the first word; transaction 1 (if any) starts at bit 4 of the next word.
  logic second_needed;
  assign second_needed = (second_nbytes != 4'd0);

  logic [7:0]      sel_txn;
  logic [XLEN-1:0] dat_txn;
  logic [XLEN-1:0] word_addr_txn;
  always_comb begin
    if (!second_active) begin
      sel_txn       = (8'hFF >> (8 - first_nbytes)) << addr_off;
      dat_txn       = store_lo << (addr_off * 8);
      word_addr_txn = {ex_mem_reg_i.alu_result[XLEN-1:2], 2'b00};
    end else begin
      sel_txn       = ((8'hFF >> (8 - second_nbytes)) << 4);
      dat_txn       = (store_lo >> (first_nbytes * 8)) << 32;
      word_addr_txn = ({ex_mem_reg_i.alu_result[XLEN-1:2], 2'b00} + 64'd4);
    end
  end

  // Load merge: the first chunk is live bus data for single-transaction
  // accesses, or latched (from transaction 0) once the second transaction
  // is in flight and dwb_dat_i carries the second word.
  logic [XLEN-1:0] load_first;
  logic [XLEN-1:0] second_chunk;
  assign second_chunk = second_needed ?
                        ((dwb_dat_i >> 32) & (64'hFFFFFFFFFFFFFFFF >> (64 - second_nbytes * 8))) :
                        '0;
  logic [XLEN-1:0] chunk0_live;
  assign chunk0_live = (dwb_dat_i >> (addr_off * 8)) &
                       (64'hFFFFFFFFFFFFFFFF >> (64 - first_nbytes * 8));
  logic [XLEN-1:0] load_merged;
  assign load_merged = (second_needed ? load_first : chunk0_live) |
                       (second_chunk << (first_nbytes * 8));

  // Sign/zero extension from the low-aligned merged value
  logic [XLEN-1:0] load_data_raw;
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {56'b0, load_merged[7:0]};
        end else begin
          load_data_raw = {{56{load_merged[7]}}, load_merged[7:0]};
        end
      end
      MEM_HALF: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {48'b0, load_merged[15:0]};
        end else begin
          load_data_raw = {{48{load_merged[15]}}, load_merged[15:0]};
        end
      end
      MEM_WORD: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {32'b0, load_merged[31:0]};  // LWU: zero-extend (RV64)
        end else begin
          load_data_raw = {{32{load_merged[31]}}, load_merged[31:0]};  // LW: sign-extend
        end
      end
      MEM_DWORD: begin  // RV64I: LD - full 64-bit load
        load_data_raw = load_merged;
      end
      default: load_data_raw = load_merged;
    endcase
  end

  //--------------------------------------------------------------------------
  // Exception outputs
  //--------------------------------------------------------------------------
  // No bus faults are modeled (the bus always acks), and misaligned
  // accesses are handled in hardware by splitting (see above), so no MEM
  // exception source remains. Ports are kept for future PMP/bus-error use.
  assign mem_exc_valid_o = 1'b0;
  assign mem_exc_cause_o = EXC_LOAD_MISALIGN;

  //--------------------------------------------------------------------------
  // State Machine (one bus transaction per split chunk)
  //--------------------------------------------------------------------------
  logic mem_access_needed;
  assign mem_access_needed = ex_mem_reg_i.valid && (ex_mem_reg_i.mem_read || ex_mem_reg_i.mem_write);

  // Second-transaction tracking: latched first load chunk.
  logic        second_active;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state        <= IDLE;
      second_active <= 1'b0;
      load_first   <= '0;
    end else begin
      state <= state_next;
      if (state == WAIT_ACK && dwb_ack_i && !second_active) begin
        // Transaction 0 done: latch its load bytes (the whole result for
        // single-transaction accesses, the low chunk for split ones).
        second_active <= second_needed;
        load_first    <= (dwb_dat_i >> (addr_off * 8)) &
                         (64'hFFFFFFFFFFFFFFFF >> (64 - first_nbytes * 8));
      end else if (state == IDLE) begin
        second_active <= 1'b0;
        load_first    <= '0;
      end
    end
  end

  always_comb begin
    state_next = state;
    case (state)
      IDLE: begin
        if (mem_access_needed) begin
          state_next = ACCESS;
        end
      end
      ACCESS: begin
        state_next = WAIT_ACK;
      end
      WAIT_ACK: begin
        if (dwb_ack_i) begin
          // More chunks? Run the second transaction, else done.
          if (second_needed && !second_active) begin
            state_next = ACCESS;
          end else begin
            state_next = IDLE;
          end
        end
      end
      default: state_next = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // Wishbone Interface (driven by the active split transaction)
  //--------------------------------------------------------------------------
  assign dwb_cyc_o = (state == ACCESS) || (state == WAIT_ACK);
  assign dwb_stb_o = (state == ACCESS) || (state == WAIT_ACK && !dwb_ack_i);
  assign dwb_we_o  = ex_mem_reg_i.mem_write;
  assign dwb_adr_o = word_addr_txn;
  assign dwb_dat_o = dat_txn;
  assign dwb_sel_o = sel_txn;

  assign mem_rdata_o = load_data_raw;

  //--------------------------------------------------------------------------
  // Stall Signal
  //--------------------------------------------------------------------------
  // The front end stays stalled until the LAST transaction ack: releasing
  // stall (and letting EX/MEM advance) after the first ack of a split
  // access would retire the load/store early and corrupt the second
  // transaction's parameters.
  logic last_ack;
  assign last_ack = (state == WAIT_ACK) && dwb_ack_i && !(second_needed && !second_active);
  assign mem_stall_o = mem_access_needed && (state != IDLE || !dwb_ack_i) && !last_ack;

endmodule : rv64xo3_mem
