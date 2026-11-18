// File:        sky130_scl_9T_tiecells.v
// Author:      Isaac Hagedorn
// Date:        2026-10-11
// Description: Models of the sky130_scl_9T tie cells TIEHI and TIELO for gate-level simulation. The PDK's cell models do not include them (they are in the phyCells library).
`timescale 1ns/10ps
`celldefine
module TIEHI (output Y);
  assign Y = 1'b1;
endmodule
`endcelldefine

`celldefine
module TIELO (output Y);
  assign Y = 1'b0;
endmodule
`endcelldefine
