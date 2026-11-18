# File:        abstract.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Abstract views of a finished design for use as a macro: LEF and a Liberty timing model (tt). Writes abstract/<top>.lef and abstract/<top>.lib.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load final.odb
read_spef $::env(OUT_DIR)/final.spef

# clock delays inside the block go into the model; the clock source itself is ideal
set_propagated_clock [all_clocks]
set_clock_latency -source 0 [all_clocks]

set top $::env(TOP)
write_timing_model -library_name $top $::env(OUT_DIR)/abstract/$top.lib
# routing layers the block uses become full obstructions
write_abstract_lef -bloat_occupied_layers $::env(OUT_DIR)/abstract/$top.lef
