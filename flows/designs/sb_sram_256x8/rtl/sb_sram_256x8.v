// File:        sb_sram_256x8.v
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: 256 x 8 single-port weight memory built from flip-flops. Hardened as its own macro and placed in the tile.
module sb_sram_256x8 (
  input            clk,
  input            ce_in,     // chip enable
  input            we_in,     // 1 = write, 0 = read
  input      [7:0] addr_in,
  input      [7:0] wd_in,     // write data
  output reg [7:0] rd_out     // read data, held until the next read
);
  reg [7:0] mem [0:255];

  always @(posedge clk) begin
    if (ce_in) begin
      if (we_in) mem[addr_in] <= wd_in;
      else       rd_out <= mem[addr_in];
    end
  end
endmodule
