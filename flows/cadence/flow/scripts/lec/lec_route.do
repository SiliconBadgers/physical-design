// File:        lec_route.do
// Author:      Isaac Hagedorn
// Date:        2026-10-11
// Description: Conformal LEC of the synthesized netlist netlist.v (golden) against the routed logic netlist final_logic.v (revised); hard macros are black boxes.
//              Key points (ports, flip-flops, macro pins) map by name, since Innovus keeps instance names; its buffers, resized cells, swapped pins and tie cells are logic between them.
tclmode
source $::env(SCRIPTS)/lec/lec_common.tcl
set top $::env(TOP)
set out $::env(OUT_DIR)

sb_lec_start lec_route
sb_lec_libraries
read_design -verilog -golden -lastmod -noelab $out/netlist.v
elaborate_design -golden -root $top
read_design -verilog -revised -lastmod -noelab [env_or LEC_REVISED $out/final_logic.v]
elaborate_design -revised -root $top
sb_lec_black_boxes
sb_lec_compare

# back to native mode to exit
vpxmode
exit -force
