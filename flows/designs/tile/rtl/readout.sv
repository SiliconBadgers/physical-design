// File:        readout.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Result readout. Returns the accumulator chosen by res_sel, one valid/ready handshake per PE.

`include "params.svh"

module sb_readout #(
  parameter int N_ROWS   = `SB_N_ROWS,
  parameter int N_COLS   = `SB_N_COLS,
  parameter int ACC_W    = `SB_ACC_W,
  parameter int OUT_PIPE = `SB_OUT_PIPE,
  localparam int N       = N_ROWS * N_COLS,
  localparam int SEL_W   = $clog2(N)
) (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               start,       // the accumulators are final
  input  logic [N*ACC_W-1:0] acc_flat,    // PE (r,c) at index r*N_COLS + c
  input  logic [SEL_W-1:0]   res_sel,
  input  logic               res_ready,
  output logic               res_valid,
  output logic [ACC_W-1:0]   res_data,
  output logic               done
);
  logic             active_q;            // results are available
  logic [SEL_W:0]   count_q;             // handshakes so far
  logic             take, last;
  logic [ACC_W-1:0] mux;                 // selected accumulator

  always_comb begin
    mux = acc_flat[res_sel*ACC_W +: ACC_W];
  end

  if (OUT_PIPE == 0) begin : g_comb
    assign res_data  = mux;
    assign res_valid = active_q;
  end else begin : g_reg
    logic [ACC_W-1:0] data_q;
    logic [SEL_W-1:0] sel_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        data_q <= '0;
        sel_q  <= '0;
      end else begin
        data_q <= mux;
        sel_q  <= res_sel;
      end
    end
    assign res_data  = data_q;
    // valid once data_q matches res_sel
    assign res_valid = active_q && (sel_q == res_sel);
  end

  assign take = res_valid && res_ready;
  assign last = (count_q == (SEL_W+1)'(N - 1));
  assign done = take && last;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_q <= 1'b0;
      count_q  <= '0;
    end else if (start) begin
      active_q <= 1'b1;
      count_q  <= '0;
    end else if (take) begin
      count_q  <= count_q + 1'b1;
      if (last) active_q <= 1'b0;
    end
  end
endmodule
