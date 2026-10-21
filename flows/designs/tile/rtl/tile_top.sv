// File:        tile_top.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Top level of sb_systolic_tile, an int8 output-stationary systolic MAC array. Computes C = A x W for one tile.

`include "params.svh"

module sb_systolic_tile #(
  parameter int N_ROWS     = `SB_N_ROWS,
  parameter int N_COLS     = `SB_N_COLS,
  parameter int DATA_W     = `SB_DATA_W,
  parameter int ACC_W      = `SB_ACC_W,
  parameter int MUL_PIPE   = `SB_MUL_PIPE,
  parameter int ACC_PIPE   = `SB_ACC_PIPE,
  parameter int OUT_PIPE   = `SB_OUT_PIPE,
  parameter int WBUF_DEPTH = `SB_WBUF_DEPTH,
  localparam int K_W       = $clog2(WBUF_DEPTH),
  localparam int COL_W     = (N_COLS > 1) ? $clog2(N_COLS) : 1,
  localparam int SEL_W     = $clog2(N_ROWS * N_COLS)
) (
  input  logic                     clk,
  input  logic                     rst_n,       // asynchronous, active low

  // Configuration (change only while idle)
  input  logic [K_W-1:0]           cfg_k_len,   // number of beats - 1

  // Weight load (while idle): W[k][col] at w_addr = {col, k}
  input  logic                     w_we,
  input  logic [COL_W+K_W-1:0]     w_addr,
  input  logic [DATA_W-1:0]        w_data,

  // Activation stream
  input  logic                     act_valid,
  output logic                     act_ready,
  input  logic [N_ROWS*DATA_W-1:0] act_data,    // row r in [r*DATA_W +: DATA_W]

  // Results
  input  logic [SEL_W-1:0]         res_sel,     // row * N_COLS + col
  output logic                     res_valid,
  input  logic                     res_ready,
  output logic [ACC_W-1:0]         res_data
);
  // --- reset synchronizer ---
  logic rst_sync_n;
  sb_reset_sync u_reset_sync (.clk(clk), .rst_n_i(rst_n), .rst_n_o(rst_sync_n));

  // --- control ---
  logic           en, clear, sram_rd, readout_start, readout_done;
  logic [K_W-1:0] rd_addr;

  sb_pe_ctrl #(
    .N_ROWS(N_ROWS), .N_COLS(N_COLS), .MUL_PIPE(MUL_PIPE), .ACC_PIPE(ACC_PIPE),
    .WBUF_DEPTH(WBUF_DEPTH)
  ) u_ctrl (
    .clk(clk), .rst_n(rst_sync_n), .cfg_k_len(cfg_k_len),
    .act_valid(act_valid), .w_we(w_we), .readout_done(readout_done),
    .act_ready(act_ready), .en(en), .clear(clear), .sram_rd(sram_rd),
    .rd_addr(rd_addr), .readout_start(readout_start)
  );

  // --- weight buffers: one SRAM per column ---
  logic [N_COLS*DATA_W-1:0] w_rd;          // column c in [c*DATA_W +: DATA_W]
  logic [COL_W-1:0]         w_col;
  logic [K_W-1:0]           w_k;
  assign w_col = w_addr[COL_W+K_W-1:K_W];
  assign w_k   = w_addr[K_W-1:0];

  for (genvar c = 0; c < N_COLS; c++) begin : g_wbuf
    sb_sram_256x8 u_sram (
      .clk     (clk),
      .ce_in   ((w_we && (w_col == COL_W'(c))) || sram_rd),
      .we_in   (w_we),
      .addr_in (w_we ? w_k : rd_addr),
      .wd_in   (w_data),
      .rd_out  (w_rd[c*DATA_W +: DATA_W])
    );
  end

  // --- input stage: accepted beat, aligned with the SRAM read data ---
  logic [N_ROWS*DATA_W-1:0] act_q;
  logic                     act_v_q;
  always_ff @(posedge clk or negedge rst_sync_n) begin
    if (!rst_sync_n) begin
      act_q   <= '0;
      act_v_q <= 1'b0;
    end else if (en) begin
      act_q   <= sram_rd ? act_data : '0;
      act_v_q <= sram_rd;
    end
  end

  // --- skew: row r delayed r cycles, column c delayed c cycles ---
  logic [N_ROWS*DATA_W-1:0] a_left;   // into PE(r, 0)
  logic [N_ROWS-1:0]        v_left;
  logic [N_COLS*DATA_W-1:0] w_top;    // into PE(0, c)

  for (genvar r = 0; r < N_ROWS; r++) begin : g_row_skew
    logic [(r+1)*DATA_W-1:0] a_sh;
    logic [r:0]              v_sh;
    assign a_sh[DATA_W-1:0] = act_q[r*DATA_W +: DATA_W];
    assign v_sh[0]          = act_v_q;
    for (genvar s = 1; s <= r; s++) begin : g_stage
      always_ff @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
          a_sh[s*DATA_W +: DATA_W] <= '0;
          v_sh[s]                  <= 1'b0;
        end else if (en) begin
          a_sh[s*DATA_W +: DATA_W] <= a_sh[(s-1)*DATA_W +: DATA_W];
          v_sh[s]                  <= v_sh[s-1];
        end
      end
    end
    assign a_left[r*DATA_W +: DATA_W] = a_sh[r*DATA_W +: DATA_W];
    assign v_left[r]                  = v_sh[r];
  end

  for (genvar c = 0; c < N_COLS; c++) begin : g_col_skew
    logic [(c+1)*DATA_W-1:0] w_sh;
    assign w_sh[DATA_W-1:0] = w_rd[c*DATA_W +: DATA_W];
    for (genvar s = 1; s <= c; s++) begin : g_stage
      always_ff @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n)  w_sh[s*DATA_W +: DATA_W] <= '0;
        else if (en)      w_sh[s*DATA_W +: DATA_W] <= w_sh[(s-1)*DATA_W +: DATA_W];
      end
    end
    assign w_top[c*DATA_W +: DATA_W] = w_sh[c*DATA_W +: DATA_W];
  end

  // --- PE array: a flows right, w flows down ---
  localparam int NPE = N_ROWS * N_COLS;
  logic [N_ROWS*(N_COLS+1)*DATA_W-1:0] a_h;   // activation into PE(r,c) from the left
  logic [N_ROWS*(N_COLS+1)-1:0]        v_h;   // valid, travels with a
  logic [(N_ROWS+1)*N_COLS*DATA_W-1:0] w_v;   // weight into PE(r,c) from above
  logic [NPE*ACC_W-1:0]                acc_flat;

  for (genvar r = 0; r < N_ROWS; r++) begin : g_a_in
    assign a_h[(r*(N_COLS+1))*DATA_W +: DATA_W] = a_left[r*DATA_W +: DATA_W];
    assign v_h[r*(N_COLS+1)]                    = v_left[r];
  end
  for (genvar c = 0; c < N_COLS; c++) begin : g_w_in
    assign w_v[c*DATA_W +: DATA_W] = w_top[c*DATA_W +: DATA_W];
  end

  for (genvar r = 0; r < N_ROWS; r++) begin : g_r
    for (genvar c = 0; c < N_COLS; c++) begin : g_c
      sb_pe #(.DATA_W(DATA_W), .ACC_W(ACC_W), .MUL_PIPE(MUL_PIPE), .ACC_PIPE(ACC_PIPE)) u_pe (
        .clk   (clk),
        .rst_n (rst_sync_n),
        .en    (en),
        .clear (clear),
        .a_in  (a_h[(r*(N_COLS+1)+c)*DATA_W +: DATA_W]),
        .w_in  (w_v[(r*N_COLS+c)*DATA_W +: DATA_W]),
        .v_in  (v_h[r*(N_COLS+1)+c]),
        .a_out (a_h[(r*(N_COLS+1)+c+1)*DATA_W +: DATA_W]),
        .w_out (w_v[((r+1)*N_COLS+c)*DATA_W +: DATA_W]),
        .v_out (v_h[r*(N_COLS+1)+c+1]),
        .acc   (acc_flat[(r*N_COLS+c)*ACC_W +: ACC_W])
      );
    end
  end

  // --- readout ---
  sb_readout #(.N_ROWS(N_ROWS), .N_COLS(N_COLS), .ACC_W(ACC_W), .OUT_PIPE(OUT_PIPE)) u_readout (
    .clk(clk), .rst_n(rst_sync_n), .start(readout_start), .acc_flat(acc_flat),
    .res_sel(res_sel), .res_ready(res_ready), .res_valid(res_valid),
    .res_data(res_data), .done(readout_done)
  );
endmodule
