// IronCore MEM Stage - Memory Access
// Handles load/store operations via Wishbone interface

import ironcore_pkg::*;
module ironcore_mem (
    input logic clk_i,
    input logic rst_ni,

    // Pipeline register input
    input ironcore_pkg::ex_mem_reg_t ex_mem_reg_i,

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
  // Byte Lane Selection and Data Alignment
  //--------------------------------------------------------------------------
  logic [1:0] addr_offset;
  assign addr_offset = ex_mem_reg_i.alu_result[1:0];

  // Generate byte select based on access width and alignment
  logic [7:0] byte_sel;  // Extended to 8 bytes for RV64
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE: begin
        case (addr_offset)
          2'b00:   byte_sel = 8'b0000_0001;
          2'b01:   byte_sel = 8'b0000_0010;
          2'b10:   byte_sel = 8'b0000_0100;
          2'b11:   byte_sel = 8'b0000_1000;
          default: byte_sel = 8'b0000_0001;
        endcase
      end
      MEM_HALF: begin
        case (addr_offset[1])
          1'b0: byte_sel = 8'b0000_0011;
          1'b1: byte_sel = 8'b0000_1100;
          default: byte_sel = 8'b0000_0011;
        endcase
      end
      MEM_WORD: begin
        byte_sel = 8'b0000_1111;
      end
      MEM_DWORD: begin  // RV64I: 64-bit access
        byte_sel = 8'b1111_1111;
      end
      default: byte_sel = 8'b1111_1111;
    endcase
  end

  // Store data alignment (shift data to correct byte lanes)
  logic [XLEN-1:0] store_data_aligned;
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE: begin
        case (addr_offset)
          2'b00:   store_data_aligned = {56'b0, ex_mem_reg_i.rs2_data[7:0]};
          2'b01:   store_data_aligned = {48'b0, ex_mem_reg_i.rs2_data[7:0], 8'b0};
          2'b10:   store_data_aligned = {40'b0, ex_mem_reg_i.rs2_data[7:0], 16'b0};
          2'b11:   store_data_aligned = {32'b0, ex_mem_reg_i.rs2_data[7:0], 24'b0};
          default: store_data_aligned = {56'b0, ex_mem_reg_i.rs2_data[7:0]};
        endcase
      end
      MEM_HALF: begin
        case (addr_offset[1])
          1'b0: store_data_aligned = {48'b0, ex_mem_reg_i.rs2_data[15:0]};
          1'b1: store_data_aligned = {32'b0, ex_mem_reg_i.rs2_data[15:0], 16'b0};
          default: store_data_aligned = {48'b0, ex_mem_reg_i.rs2_data[15:0]};
        endcase
      end
      MEM_WORD: begin
        store_data_aligned = {32'b0, ex_mem_reg_i.rs2_data[31:0]};
      end
      MEM_DWORD: begin  // RV64I: full 64-bit store
        store_data_aligned = ex_mem_reg_i.rs2_data;
      end
      default: store_data_aligned = ex_mem_reg_i.rs2_data;
    endcase
  end

  //--------------------------------------------------------------------------
  // Misalignment Detection
  //--------------------------------------------------------------------------
  logic misaligned_load, misaligned_store;

  always_comb begin
    // Check load misalignment
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE:    misaligned_load = 1'b0;  // Always aligned
      MEM_HALF:    misaligned_load = ex_mem_reg_i.alu_result[0];  // Must be 2-byte aligned
      MEM_WORD:    misaligned_load = |ex_mem_reg_i.alu_result[1:0];  // Must be 4-byte aligned
      MEM_DWORD:   misaligned_load = |ex_mem_reg_i.alu_result[2:0];  // Must be 8-byte aligned (RV64)
      default:     misaligned_load = 1'b0;
    endcase

    // Check store misalignment
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE:    misaligned_store = 1'b0;  // Always aligned
      MEM_HALF:    misaligned_store = ex_mem_reg_i.alu_result[0];  // Must be 2-byte aligned
      MEM_WORD:    misaligned_store = |ex_mem_reg_i.alu_result[1:0];  // Must be 4-byte aligned
      MEM_DWORD:   misaligned_store = |ex_mem_reg_i.alu_result[2:0];  // Must be 8-byte aligned (RV64)
      default:     misaligned_store = 1'b0;
    endcase
  end

  // Generate exception signals
  assign mem_exc_valid_o = ex_mem_reg_i.valid &&
                           ((ex_mem_reg_i.mem_read && misaligned_load) ||
                            (ex_mem_reg_i.mem_write && misaligned_store));

  assign mem_exc_cause_o = ex_mem_reg_i.mem_read ? EXC_LOAD_MISALIGN : EXC_STORE_MISALIGN;

  //--------------------------------------------------------------------------
  // State Machine
  //--------------------------------------------------------------------------
  logic mem_access_needed;
  // Don't initiate memory access if there's a misalignment exception
  assign mem_access_needed = ex_mem_reg_i.valid && (ex_mem_reg_i.mem_read || ex_mem_reg_i.mem_write) &&
                             !mem_exc_valid_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
    end else begin
      state <= state_next;
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
          state_next = IDLE;
        end
      end
      default: state_next = IDLE;
    endcase
  end

  //--------------------------------------------------------------------------
  // Wishbone Interface
  //--------------------------------------------------------------------------
  assign dwb_cyc_o = (state == ACCESS) || (state == WAIT_ACK);
  assign dwb_stb_o = (state == ACCESS) || (state == WAIT_ACK && !dwb_ack_i);
  assign dwb_we_o  = ex_mem_reg_i.mem_write;
  assign dwb_adr_o = {ex_mem_reg_i.alu_result[XLEN-1:2], 2'b00};  // Word-aligned
  assign dwb_dat_o = store_data_aligned;
  assign dwb_sel_o = byte_sel;

  //--------------------------------------------------------------------------
  // Load Data Processing (sign/zero extension)
  //--------------------------------------------------------------------------
  logic [XLEN-1:0] load_data_raw;
  logic [7:0] load_byte;
  logic [15:0] load_half;

  // Extract correct byte/halfword from memory data
  always_comb begin
    case (addr_offset)
      2'b00:   load_byte = dwb_dat_i[7:0];
      2'b01:   load_byte = dwb_dat_i[15:8];
      2'b10:   load_byte = dwb_dat_i[23:16];
      2'b11:   load_byte = dwb_dat_i[31:24];
      default: load_byte = dwb_dat_i[7:0];
    endcase

    case (addr_offset[1])
      1'b0: load_half = dwb_dat_i[15:0];
      1'b1: load_half = dwb_dat_i[31:16];
      default: load_half = dwb_dat_i[15:0];
    endcase
  end

  // Sign/zero extension
  always_comb begin
    case (ex_mem_reg_i.mem_width)
      MEM_BYTE: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {56'b0, load_byte};
        end else begin
          load_data_raw = {{56{load_byte[7]}}, load_byte};
        end
      end
      MEM_HALF: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {48'b0, load_half};
        end else begin
          load_data_raw = {{48{load_half[15]}}, load_half};
        end
      end
      MEM_WORD: begin
        if (ex_mem_reg_i.mem_unsigned) begin
          load_data_raw = {32'b0, dwb_dat_i[31:0]};  // LWU: zero-extend (RV64)
        end else begin
          load_data_raw = {{32{dwb_dat_i[31]}}, dwb_dat_i[31:0]};  // LW: sign-extend
        end
      end
      MEM_DWORD: begin  // RV64I: LD - full 64-bit load
        load_data_raw = dwb_dat_i;
      end
      default: load_data_raw = dwb_dat_i;
    endcase
  end

  assign mem_rdata_o = load_data_raw;

  //--------------------------------------------------------------------------
  // Stall Signal
  //--------------------------------------------------------------------------
  assign mem_stall_o = mem_access_needed && (state != IDLE || !dwb_ack_i) && !(state == WAIT_ACK && dwb_ack_i);

  //--------------------------------------------------------------------------
  // Assertions
  //--------------------------------------------------------------------------
`ifndef SYNTHESIS
  // Word access must be aligned on the bus
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (dwb_stb_o && ex_mem_reg_i.mem_width == MEM_WORD) |-> ex_mem_reg_i.alu_result[1:0] == 2'b00
  )
  else $error("Misaligned word access at addr %h", ex_mem_reg_i.alu_result);

  // Halfword access must be aligned on the bus
  assert property (@(posedge clk_i) disable iff (!rst_ni)
    (dwb_stb_o && ex_mem_reg_i.mem_width == MEM_HALF) |-> ex_mem_reg_i.alu_result[0] == 1'b0
  )
  else $error("Misaligned halfword access at addr %h", ex_mem_reg_i.alu_result);
`endif

endmodule : ironcore_mem
