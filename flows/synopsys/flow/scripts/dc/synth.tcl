# File:        synth.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Design Compiler synthesis at the synthesis corner. Inputs are environment variables from synth.env, written by the Makefile; writes netlist.v, synth.sdc, synth.ddc, synth.svf and synth_*.rpt in the build folder.

source $::env(SCRIPTS)/util/metrics.tcl

set top       $::env(TOP)                       ;# top module
set rtl_files $::env(RTL_FILES)                 ;# RTL files, packages first
set incdirs   [env_or RTL_INCDIRS ""]           ;# folders searched by `include
set defines   [env_or RTL_DEFINES ""]           ;# macros, NAME or NAME=VALUE
set sdc       $::env(SDC_FILE)                  ;# constraints
set cell_db   $::env(CELL_DB)                   ;# standard cells (.db) at the synthesis corner
set macro_dbs [env_or MACRO_DBS ""]             ;# hard macro timing models (.db) at the synthesis corner
set dont_use  [env_or DONT_USE ""]              ;# cell name patterns synthesis must not use
set compile   [env_or DC_COMPILE compile_ultra] ;# compile_ultra or compile
set flatten   [env_or SYNTH_FLATTEN 1]          ;# 1 = one flat netlist
set retime    [env_or SYNTH_RETIME 0]           ;# 1 = compile_ultra -retime

# --- 1. libraries ---
# target_library: cells DC may pick. link_library: where DC looks up every instance (hard macros too).
set_app_var search_path       [concat . $incdirs [get_app_var search_path]]
set_app_var target_library    $cell_db
set_app_var synthetic_library dw_foundation.sldb   ;# DesignWare (adders, comparators)
set_app_var link_library      [concat * $cell_db $macro_dbs dw_foundation.sldb]
set_svf synth.svf                                   ;# change log for Formality

# --- 2. read the RTL ---
define_design_lib WORK -path ./WORK
set_app_var hdlin_check_no_latch true   ;# warn for every inferred latch
set analyze_args [list -format sverilog]
if {[llength $defines]} { lappend analyze_args -define $defines }
if {[analyze {*}$analyze_args $rtl_files] eq "0"} { error "analyze failed (see the messages above)" }
if {[elaborate $top] eq "0"} { error "elaborate failed (see the messages above)" }
current_design $top
if {[link] eq "0"} { error "link could not resolve every instance (see the LINK messages above)" }
if {$flatten} { ungroup -all -flatten }

# --- 3. constraints and checks before compile ---
if {[read_sdc $sdc] eq "0"} { error "read_sdc $sdc failed" }
sb_report synth_check_design.rpt { check_design }
sb_report synth_check_timing.rpt { check_timing }

# --- 4. compile ---
foreach pattern $dont_use {
    set cells [get_lib_cells -quiet */$pattern]
    if {[sizeof_collection $cells] > 0} { set_dont_use $cells }
}
set_fix_multiple_port_nets -all -buffer_constants   ;# no assign statements in the netlist
set compile_cmd [list $compile]
if {$retime && $compile eq "compile_ultra"} { lappend compile_cmd -retime }
if {[{*}$compile_cmd] eq "0"} { error "$compile failed" }

# --- 5. reports ---
change_names -rules verilog -hierarchy   ;# legal Verilog names in reports and netlist
sb_report synth_timing.rpt    { report_timing -delay_type max -max_paths 10 -input_pins -nets -transition_time -capacitance -significant_digits 3 }
sb_report synth_area.rpt      { report_area -nosplit }
sb_report synth_cells.rpt     { report_reference -nosplit }
sb_report synth_qor.rpt       { report_qor }
sb_report synth_violators.rpt { report_constraint -all_violators }
sb_report synth_loops.rpt     { report_timing -loops }   ;# combinational loops

# latches (level-sensitive registers) left after compile
set latches [all_registers -level_sensitive]
set fh [open synth_latches.rpt w]
puts $fh "Latches in the netlist: [sizeof_collection $latches]"
foreach_in_collection cell $latches {
    puts $fh "  [get_object_name $cell]  ([get_attribute $cell ref_name])"
}
close $fh

# --- 6. outputs ---
set_app_var verilogout_no_tri true
file delete -force netlist.v
write -format verilog -hierarchy -output netlist.v
write -format ddc -hierarchy -output synth.ddc
write_sdc synth.sdc
set_svf -off

set area [sb_try { get_attribute [current_design] area }]
sb_note "$top at [file rootname [file tail $cell_db]]: area $area um2, [sizeof_collection $latches] latch(es) -> netlist.v"
if {![file exists netlist.v]} { error "no netlist.v written" }
if {[sizeof_collection $latches] > 0} { error "the netlist has latches (synth_latches.rpt)" }
