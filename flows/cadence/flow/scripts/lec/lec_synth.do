// File:        lec_synth.do
// Author:      Isaac Hagedorn
// Date:        2026-10-11
// Description: Conformal LEC of the RTL (golden) against the synthesized netlist netlist.v (revised); hard macros are black boxes.
//              make lec runs it with LEC_SYNTH_MODE=own, or when Genus wrote no genus_lec.do.
tclmode
source $::env(SCRIPTS)/lec/lec_common.tcl
set top $::env(TOP)

sb_lec_start lec_synth
sb_lec_libraries
# golden: the RTL as Genus read it; `include files from the include directories
foreach d [env_or RTL_INCDIRS ""] { add_search_path $d -design -golden }
sb_try set_hdl_options -VERILOG_INCLUDE_DIR "sep:src"
set defines {}
foreach d [env_or RTL_DEFINES ""] { lappend defines -define $d }
read_design -sv09 -golden -lastmod -noelab {*}$defines {*}$::env(RTL_FILES)
elaborate_design -golden -root $top
# revised: the netlist
read_design -verilog -revised -lastmod -noelab [env_or LEC_REVISED $::env(OUT_DIR)/netlist.v]
elaborate_design -revised -root $top
sb_lec_black_boxes
sb_lec_compare 1

# back to native mode to exit
vpxmode
exit -force
