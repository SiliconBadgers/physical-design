// File:        pe.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: One processing element of the systolic array. Multiplies, accumulates and passes data on.

`include "params.svh"

module sb_pe #(
  parameter int DATA_W   = `SB_DATA_W,
  parameter int ACC_W    = `SB_ACC_W,
  parameter int MUL_PIPE = `SB_MUL_PIPE,
  parameter int ACC_PIPE = `SB_ACC_PIPE
) (
  input  logic                     clk,
  input  logic                     rst_n,
  input  logic                     en,       // the whole array advances
  input  logic                     clear,    // zero the accumulator (new tile)
  input  logic signed [DATA_W-1:0] a_in,     // from the left neighbour
  input  logic signed [DATA_W-1:0] w_in,     // from the neighbour above
  input  logic                     v_in,     // a_in/w_in carry real data
  output logic signed [DATA_W-1:0] a_out,
  output logic signed [DATA_W-1:0] w_out,
  output logic                     v_out,
  output logic signed [ACC_W-1:0]  acc
);
  localparam int PW = 2 * DATA_W;      // product width
  localparam int NS = MUL_PIPE + ACC_PIPE;   // pipeline stages before the adder

  // Input registers (also the outputs to the neighbours)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_out <= '0;
      w_out <= '0;
      v_out <= 1'b0;
    end else if (en) begin
      a_out <= a_in;
      w_out <= w_in;
      v_out <= v_in;
    end
  end

  // Multiply. MUL_PIPE: 1 = register the partial products, 2 = also their sum.
  localparam int H   = DATA_W / 2;
  localparam int PPW = DATA_W + H;          // partial-product width
  logic signed [PPW-1:0] pp_hi, pp_lo, pp_hi_s, pp_lo_s;
  logic signed [PW-1:0]  prod_sum, prod, p_last;
  logic                  v_last;
  sb_mul #(.W(DATA_W)) u_mul (.a(a_out), .b(w_out), .pp_hi(pp_hi), .pp_lo(pp_lo));

  if (MUL_PIPE == 0) begin : g_pp_comb
    assign pp_hi_s = pp_hi;
    assign pp_lo_s = pp_lo;
  end else begin : g_pp_q
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        pp_hi_s <= '0;
        pp_lo_s <= '0;
      end else if (en) begin
        pp_hi_s <= pp_hi;
        pp_lo_s <= pp_lo;
      end
    end
  end

  // a * b = pp_hi * 2^H + pp_lo
  assign prod_sum = (PW'(pp_hi_s) <<< H) + PW'(pp_lo_s);

  if (MUL_PIPE < 2) begin : g_prod_comb
    assign prod = prod_sum;
  end else begin : g_prod_q
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)  prod <= '0;
      else if (en) prod <= prod_sum;
    end
  end

  // ACC_PIPE stages between multiplier and adder (shift register, PW bits per stage)
  if (ACC_PIPE == 0) begin : g_acc_comb
    assign p_last = prod;
  end else begin : g_acc_pipe
    logic [ACC_PIPE*PW-1:0] prod_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)  prod_q <= '0;
      else if (en) prod_q <= (ACC_PIPE*PW)'({prod_q, prod});
    end
    assign p_last = prod_q[(ACC_PIPE-1)*PW +: PW];
  end

  // Valid bit, delayed with the data
  if (NS == 0) begin : g_v_comb
    assign v_last = v_out;
  end else begin : g_v_pipe
    logic [NS-1:0] v_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)  v_q <= '0;
      else if (en) v_q <= (NS)'({v_q, v_out});
    end
    assign v_last = v_q[NS-1];
  end

  // Accumulate
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc <= '0;
    end else if (clear) begin
      acc <= '0;
    end else if (en && v_last) begin
      acc <= acc + ACC_W'(p_last);
    end
  end
endmodule


// Partial products of a * b (b split into a signed high and an unsigned low half). W must be even.
module sb_mul #(
  parameter int W = `SB_DATA_W
) (
  input  logic signed [W-1:0]       a,
  input  logic signed [W-1:0]       b,
  output logic signed [W+W/2-1:0]   pp_hi,   // a * b[W-1:W/2]  (signed half)
  output logic signed [W+W/2-1:0]   pp_lo    // a * b[W/2-1:0]  (unsigned half)
);
  localparam int H = W / 2;
  assign pp_hi = a * $signed(b[W-1:H]);
  assign pp_lo = a * $signed({1'b0, b[H-1:0]});
endmodule
