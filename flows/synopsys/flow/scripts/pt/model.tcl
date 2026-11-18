# File:        model.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: PrimeTime timing model of the routed design at one corner, for use as a macro: extract_model with the StarRC parasitics. Inputs are environment variables from model_<corner>.env, written by the Makefile; writes abstract/<top>_<corner>.lib.

source $::env(SCRIPTS)/util/metrics.tcl

set top    $::env(TOP)
set corner $::env(CORNER)
set lib    $::env(OUT_DIR)/abstract/${top}_$corner.lib

# --- 1. libraries, routed netlist, constraints, parasitics ---
set_app_var search_path [list .]
set_app_var link_path   [concat * $::env(CELL_DB) [env_or MACRO_DBS ""]]
read_verilog $::env(NETLIST)
current_design $top
if {[link_design $top] eq "0"} { error "link_design $top failed" }
source -echo $::env(SDC_FILE)   ;# not read_sdc: it rejects non-SDC commands such as remove_from_collection (CMD-005)
if {[read_parasitics -format SPEF $::env(SPEF)] eq "0"} { error "read_parasitics $::env(SPEF) failed" }

# clock delays inside the block go into the model; the clock source itself is ideal
set_propagated_clock [all_clocks]
set_clock_latency -source 0 [all_clocks]
update_timing -full

# --- 2. model ---
file delete -force $lib
extract_model -library_cell -format lib -output [file rootname $lib]
if {![file exists $lib]} { error "extract_model wrote no $lib" }

# library name <top>_<corner>, so the models of all corners can be loaded together
set fh [open $lib]
set text [read $fh]
close $fh
if {![regsub {library\s*\([^)]*\)} $text "library (${top}_$corner)" text]} { error "no library group in $lib" }
set fh [open $lib w]
puts -nonewline $fh $text
close $fh
sb_note "timing model of $top at $corner -> $lib"
