# File:        mmmc.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Multi-mode multi-corner setup read by Genus, Innovus and Tempus (read_mmmc): ss, tt and ff libraries (with the macros' timing models), Quantus RC corners and the design SDC.
#              SETUP_CORNERS and HOLD_CORNERS pick the corners each check runs at.

# library set, RC corner and delay corner per corner; the tie-cell library (LIB_EXTRA) is the same at every corner
foreach {c temp} {ss 125 tt 25 ff 0} {
    set macro_libs [expr {[info exists ::env(MACRO_LIB_$c)] ? $::env(MACRO_LIB_$c) : ""}]
    create_library_set -name libs_$c -timing [concat $::env(LIB_$c) $::env(LIB_EXTRA) $macro_libs]
    create_timing_condition -name cond_$c -library_sets [list libs_$c]
    create_rc_corner -name rc_$c -temperature $temp -qrc_tech $::env(QRC_TECH)
    create_delay_corner -name dc_$c -timing_condition cond_$c -rc_corner rc_$c
}

# one mode: the design SDC, plus PROP_SDC (propagated clocks) for sign-off timing
set sdc_files [list $::env(SDC_FILE)]
if {[info exists ::env(PROP_SDC)] && $::env(PROP_SDC) ne ""} { lappend sdc_files $::env(PROP_SDC) }
create_constraint_mode -name func -sdc_files $sdc_files

# analysis view = mode + delay corner
foreach c {ss tt ff} {
    create_analysis_view -name view_$c -constraint_mode func -delay_corner dc_$c
}

# setup and hold views from the corner lists; power at typical
set setup_views {}
foreach c $::env(SETUP_CORNERS) { lappend setup_views view_$c }
set hold_views {}
foreach c $::env(HOLD_CORNERS) { lappend hold_views view_$c }
set_analysis_view -setup $setup_views -hold $hold_views -leakage view_tt -dynamic view_tt
