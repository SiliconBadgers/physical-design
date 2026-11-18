# File:        synth.tcl
# Author:      Isaac Hagedorn
# Date:        2026-11-17
# Description: Design Compiler synthesis for the PPA flow. FuseSoC's project script sets TOP_MODULE and READ_SOURCES and
#              sources this file in the run folder; settings.tcl (written by the Makefile) sets the effort, the library
#              and, with CLOCK_NS, the clock period. Writes reports/*.rpt, reports/metrics.txt and netlist.v.

if {[catch {
    source settings.tcl

    # --- libraries ---
    set_app_var search_path       [concat . [get_app_var search_path]]
    set_app_var target_library    $cell_db
    set_app_var synthetic_library dw_foundation.sldb
    set_app_var link_library      [concat * $cell_db dw_foundation.sldb]
    set_app_var hdlin_check_no_latch true

    # --- read the RTL (the file list comes from the core) ---
    define_design_lib work -path ./work
    source ${READ_SOURCES}.tcl
    if {[elaborate $TOP_MODULE] eq "0"} { error "elaborate failed (see the messages above)" }
    current_design $TOP_MODULE
    if {[link] eq "0"} { error "link could not resolve every instance (see the LINK messages above)" }

    # --- constraints ---
    # source, not read_sdc: read_sdc skips commands it doesn't know and still returns 1
    source -echo synth.sdc
    foreach pattern $dont_use {
        set cells [get_lib_cells -quiet */$pattern]
        if {[sizeof_collection $cells] > 0} { set_dont_use $cells }
    }
    file mkdir reports
    redirect reports/check_design.rpt { check_design }

    # --- compile ---
    # low: compile; medium: compile_ultra; high: compile_ultra, then a second incremental compile_ultra
    switch $effort {
        low     { set steps {compile} }
        medium  { set steps {compile_ultra} }
        high    { set steps {compile_ultra {compile_ultra -incremental}} }
        default { error "EFFORT must be low, medium or high (got $effort)" }
    }
    set_fix_multiple_port_nets -all -buffer_constants
    foreach step $steps {
        if {[{*}$step] eq "0"} { error "$step failed" }
    }

    # --- reports ---
    change_names -rules verilog -hierarchy
    redirect reports/qor.rpt       { report_qor }
    redirect reports/area.rpt      { report_area -nosplit }
    redirect reports/area_hier.rpt { report_area -hierarchy -nosplit }
    redirect reports/timing.rpt    { report_timing -delay_type max -max_paths 5 -nosplit }
    redirect reports/power.rpt     { report_power -nosplit }
    redirect reports/violators.rpt { report_constraint -all_violators -nosplit }
    write -format verilog -hierarchy -output netlist.v

    # numbers the table needs that the reports don't print in one place
    set wns ""
    set path [get_timing_paths -delay_type max -max_paths 1]
    if {[sizeof_collection $path] > 0} { set wns [get_attribute $path slack] }
    set tns 0.0
    foreach_in_collection p [get_timing_paths -delay_type max -max_paths 100000 -nworst 1 -slack_lesser_than 0] {
        set tns [expr {$tns + [get_attribute $p slack]}]
    }
    set clock_ns ""
    set clocks [get_clocks -quiet *]
    if {[sizeof_collection $clocks] > 0} { set clock_ns [get_attribute [index_collection $clocks 0] period] }
    set fh [open reports/metrics.txt w]
    puts $fh "wns_ns $wns"
    puts $fh "tns_ns $tns"
    puts $fh "clock_ns $clock_ns"
    puts $fh "cells [sizeof_collection [get_cells -hierarchical -filter {is_hierarchical == false}]]"
    puts $fh "latches [sizeof_collection [all_registers -level_sensitive]]"
    close $fh
} err]} {
    puts "PPA ERROR: $err"
    exit 1
}
exit 0
