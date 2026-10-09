# File:        abstract.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Abstract views of a finished design for use as a hard macro: LEF with its power straps as pins, and a Liberty timing model per corner.
#              Writes abstract/<top>.lef and abstract/<top>_<corner>.lib; make copies the GDS and the LVS netlist next to them.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open finish
set top   $::env(TOP)
set dir   $::env(OUT_DIR)/abstract
set layer $::env(MAX_ROUTING_LAYER)   ;# the block's top layer: power pins on it, nothing above it
file mkdir $dir

# every corner active, with its extracted wires
set views {}
foreach c {ss tt ff} { lappend views view_$c }
set_analysis_view -setup $views -hold $views -leakage view_tt -dynamic view_tt
foreach c {ss tt ff} { read_spef -rc_corner rc_$c $::env(OUT_DIR)/final_$c.spef }

# clock delays inside the block go into the model; the clock source itself is ideal
set_interactive_constraint_modes [get_db constraint_modes .name]
set_propagated_clock [all_clocks]
set_clock_latency -source 0 [all_clocks]
set_interactive_constraint_modes {}

# timing model per corner (Stylus command, else the legacy one)
foreach c {ss tt ff} {
    set lib $dir/${top}_$c.lib
    file delete $lib
    if {[catch {write_timing_model -view view_$c -cell_name $top -lib_name ${top}_$c $lib} msg]} {
        puts "SB-WARNING: write_timing_model failed ($msg); trying do_extract_model"
        do_extract_model -view view_$c -cell_name $top -lib_name ${top}_$c $lib
    }
    if {![file exists $lib]} { error "no timing model written for $c" }
}

# LEF: the power straps on the top layer as pins, obstructions on every layer up to it
write_lef_abstract -5.8 -stripe_pins -pg_pin_layers [list $layer] -specify_top_layer $layer $dir/$top.lef
if {![file exists $dir/$top.lef]} { error "no LEF written" }

sb_done abstract
exit
