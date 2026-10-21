// File:        reset_sync.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Two-flop reset synchronizer. Asserts asynchronously, releases on clk.

module sb_reset_sync (
  input  logic clk,
  input  logic rst_n_i,     // asynchronous, from the pin
  output logic rst_n_o      // asserts asynchronously, releases on clk
);
  logic stage1_q;

  always_ff @(posedge clk or negedge rst_n_i) begin
    if (!rst_n_i) begin
      stage1_q <= 1'b0;
      rst_n_o  <= 1'b0;
    end else begin
      stage1_q <= 1'b1;
      rst_n_o  <= stage1_q;
    end
  end
endmodule
