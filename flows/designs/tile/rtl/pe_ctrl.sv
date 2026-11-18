// File:        pe_ctrl.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Controller of the systolic tile. Accepts K activation beats, drains the array, then starts the readout.

`include "params.svh"

module sb_pe_ctrl #(
  parameter int N_ROWS     = `SB_N_ROWS,
  parameter int N_COLS     = `SB_N_COLS,
  parameter int MUL_PIPE   = `SB_MUL_PIPE,
  parameter int ACC_PIPE   = `SB_ACC_PIPE,
  parameter int WBUF_DEPTH = `SB_WBUF_DEPTH,
  localparam int K_W       = $clog2(WBUF_DEPTH)
) (
  input  logic           clk,
  input  logic           rst_n,
  input  logic [K_W-1:0] cfg_k_len,      // number of beats - 1
  input  logic           act_valid,
  input  logic           w_we,           // a weight write is happening
  input  logic           readout_done,
  output logic           act_ready,
  output logic           en,             // advance the array (every PE)
  output logic           clear,          // zero all accumulators
  output logic           sram_rd,        // read the weight buffers ...
  output logic [K_W-1:0] rd_addr,        // ... at this address
  output logic           readout_start
);
  localparam int DRAIN   = N_ROWS + N_COLS + MUL_PIPE + ACC_PIPE;   // drain length (cycles)
  localparam int DRAIN_W = $clog2(DRAIN + 1);

  localparam logic [1:0] S_IDLE    = 2'd0;   // weights may be loaded
  localparam logic [1:0] S_COMPUTE = 2'd1;   // one beat per accepted cycle
  localparam logic [1:0] S_DRAIN   = 2'd2;   // last beat moves through the array
  localparam logic [1:0] S_READOUT = 2'd3;   // results read through sb_readout

  logic [1:0]       state_q, state_d;
  logic [K_W-1:0]   k_q, k_d;               // beat counter
  logic [DRAIN_W-1:0] drain_q, drain_d;     // drain cycle counter

  always_comb begin
    // Defaults
    state_d       = state_q;
    k_d           = k_q;
    drain_d       = drain_q;
    act_ready     = 1'b0;
    en            = 1'b0;
    clear         = 1'b0;
    sram_rd       = 1'b0;
    readout_start = 1'b0;

    case (state_q)
      S_IDLE: begin
        act_ready = !w_we;
        if (act_valid && !w_we) begin
          clear   = 1'b1;
          en      = 1'b1;
          sram_rd = 1'b1;
          k_d     = 1;
          drain_d = '0;
          state_d = (cfg_k_len == '0) ? S_DRAIN : S_COMPUTE;
        end
      end
      S_COMPUTE: begin
        act_ready = 1'b1;
        if (act_valid) begin
          en      = 1'b1;
          sram_rd = 1'b1;
          k_d     = k_q + 1'b1;
          if (k_q == cfg_k_len) state_d = S_DRAIN;
        end
      end
      S_DRAIN: begin
        en      = 1'b1;
        drain_d = drain_q + 1'b1;
        if (drain_q == DRAIN_W'(DRAIN - 1)) begin
          state_d       = S_READOUT;
          readout_start = 1'b1;
        end
      end
      default: begin  // S_READOUT
        if (readout_done) state_d = S_IDLE;
      end
    endcase
  end

  assign rd_addr = (state_q == S_IDLE) ? '0 : k_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_IDLE;
      k_q     <= '0;
      drain_q <= '0;
    end else begin
      state_q <= state_d;
      k_q     <= k_d;
      drain_q <= drain_d;
    end
  end
endmodule
