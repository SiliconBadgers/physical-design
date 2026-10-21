# File:        sta.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: PrimeTime timing at one corner: the synthesized netlist before layout (sta_<corner>), or the routed netlist with StarRC parasitics (signoff_<corner>). Inputs are environment variables from <name>.env, written by the Makefile; writes <name>.rpt and <name>.json.

source $::env(SCRIPTS)/util/metrics.tcl

set top    $::env(TOP)
set corner $::env(CORNER)              ;# ss, tt or ff
set name   $::env(SB_STAGE)            ;# sta_<corner> or signoff_<corner>
set out    $::env(OUT_DIR)
set spef   [env_or SPEF ""]            ;# routed parasitics; empty = before layout
set rpt    $out/$name.rpt

# --- 1. libraries, netlist, constraints, parasitics ---
set_app_var search_path [list .]
set_app_var link_path   [concat * $::env(CELL_DB) [env_or MACRO_DBS ""]]   ;# cells and hard macros at this corner
read_verilog $::env(NETLIST)
current_design $top
if {[link_design $top] eq "0"} { error "link_design $top failed" }
source -echo $::env(SDC_FILE)   ;# not read_sdc: it rejects non-SDC commands such as remove_from_collection (CMD-005)
if {$spef ne ""} {
    set_propagated_clock [all_clocks]   ;# clock arrival from the built tree
    if {[read_parasitics -format SPEF $spef] eq "0"} { error "read_parasitics $spef failed" }
}
update_timing -full

# --- 2. report ---
close [open $rpt w]
sb_section $rpt "check_timing: unconstrained endpoints, missing input delays, loops" { check_timing -verbose }
sb_section $rpt "Analysis coverage (untested = not timed)" { report_analysis_coverage }
if {$spef ne ""} {
    sb_section $rpt "Annotated parasitics (every net should be annotated)" { report_annotated_parasitics -check }
}
sb_section $rpt "Setup (max delay): 10 worst paths" {
    report_timing -delay_type max -max_paths 10 -slack_lesser_than infinity -nosplit -input_pins -nets -transition_time -capacitance -significant_digits 3
}
sb_section $rpt "Hold (min delay): 10 worst paths" {
    report_timing -delay_type min -max_paths 10 -slack_lesser_than infinity -nosplit -input_pins -nets -transition_time -capacitance -significant_digits 3
}
sb_section $rpt "Slack summary: WNS, TNS, violating paths" { report_global_timing }
sb_section $rpt "All violators: setup, hold, slew, capacitance, fanout" { report_constraint -all_violators -nosplit }

# --- 3. metrics ---
set period ""
foreach_in_collection clk [all_clocks] { set period [get_attribute $clk period]; break }
set setup_ws [sb_worst_slack max]
set hold_ws  [sb_worst_slack min]
lassign [sb_failing max] setup_n setup_tns
lassign [sb_failing min] hold_n hold_tns
sb_json $out/$name.json [list \
    period_ns        $period \
    setup_ws_ns      $setup_ws \
    setup_tns_ns     $setup_tns \
    setup_violations $setup_n \
    hold_ws_ns       $hold_ws \
    hold_tns_ns      $hold_tns \
    hold_violations  $hold_n ]

# which checks this corner signs off
set role {}
if {$corner in [env_or SETUP_CORNERS ss]} { lappend role setup }
if {$corner in [env_or HOLD_CORNERS ff]}  { lappend role hold }
if {![llength $role]} { set role [list "report only"] }
sb_note "$name ([join $role " and "]): setup WS $setup_ws ns ($setup_n failing), hold WS $hold_ws ns ($hold_n failing) -> $name.rpt"
