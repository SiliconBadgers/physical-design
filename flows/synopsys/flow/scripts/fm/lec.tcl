# File:        lec.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Formality equivalence check of one LEC step: synth (RTL against netlist.v, guided by synth.svf) or route (netlist.v against the routed final_logic.v). Inputs are environment variables from lec_<step>.env, written by the Makefile; writes <stage>_unmatched.rpt, _blackboxes.rpt and _failing.rpt.

source $::env(SCRIPTS)/util/metrics.tcl

set top   $::env(TOP)
set step  $::env(LEC_STEP)                    ;# synth or route
set stage $::env(SB_STAGE)                    ;# report and summary name
set rpt   $::env(OUT_DIR)/$stage              ;# report path prefix
set impl  $::env(IMPL_NETLIST)                ;# gate netlist checked against the reference
set ref   [expr {$step eq "synth" ? "RTL" : [file tail $::env(REF_NETLIST)]}]
file delete -force ${rpt}_analyze.rpt         ;# written again only when the check fails

# --- 1. setup and libraries ---
if {$step eq "synth"} {
    set_app_var synopsys_auto_setup true   ;# read the RTL as Design Compiler did
    set_svf $::env(SVF)                    ;# what synthesis renamed, merged or removed
}
# standard cells; the macros' timing models have no logic, so macro instances are black boxes
read_db [concat $::env(CELL_DB) [env_or MACRO_DBS ""]]

# --- 2. reference: the RTL (synth) or the synthesized netlist (route) ---
if {$step eq "synth"} {
    set vcs_opts {}
    foreach d [env_or RTL_INCDIRS ""] { lappend vcs_opts +incdir+$d }
    foreach d [env_or RTL_DEFINES ""] { lappend vcs_opts +define+$d }
    set read_args [list -r]
    if {[llength $vcs_opts]} { lappend read_args -vcs [join $vcs_opts " "] }
    set ok [read_sverilog {*}$read_args $::env(RTL_FILES)]
} else {
    set ok [read_verilog -r $::env(REF_NETLIST)]
}
if {$ok eq "0"} { error "reading the reference ($ref) failed (see the messages above)" }
if {[set_top r:/WORK/$top] eq "0"} { error "set_top r:/WORK/$top failed" }

# --- 3. implementation: the gate netlist ---
if {[read_verilog -i $impl] eq "0"} { error "read_verilog $impl failed" }
if {[set_top i:/WORK/$top] eq "0"} { error "set_top i:/WORK/$top failed" }

# --- 4. pair compare points by name (ports, flip-flops, black-box pins), then prove each pair ---
match
sb_report ${rpt}_unmatched.rpt  { report_unmatched_points }
sb_report ${rpt}_blackboxes.rpt { report_black_boxes }
set result [verify]
sb_report ${rpt}_failing.rpt { report_failing_points }
if {$result ne "1"} {
    sb_report ${rpt}_analyze.rpt { analyze_points -failing }
    sb_note "$stage: FAIL ($ref vs [file tail $impl]) -> ${rpt}_failing.rpt"
    error "not equivalent: read ${rpt}_failing.rpt and ${rpt}_analyze.rpt"
}
sb_note "$stage: PASS ($ref vs [file tail $impl])"
