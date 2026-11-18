// File:        params.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-09
// Description: Default parameters of sb_systolic_tile. Your track page shows how to override them for one run.
`ifndef SB_PARAMS_SVH
`define SB_PARAMS_SVH

`define SB_N_ROWS      4
`define SB_N_COLS      4
`define SB_DATA_W      8
`define SB_WBUF_DEPTH  256

// Accumulator width
`define SB_ACC_W       (2*`SB_DATA_W + $clog2(`SB_WBUF_DEPTH))

// Pipeline registers (0 = none)
`define SB_MUL_PIPE    0
`define SB_ACC_PIPE    0
`define SB_OUT_PIPE    0

`endif
