# File:        sta.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Timing analysis of the pre-layout netlist (OpenSTA inside OpenROAD). Inputs are environment variables from sta_tt.env, written by the Makefile.

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set top     $::env(TOP)              ;# top module
set corner  $::env(CORNER)           ;# tt, ss or ff
set out     [env_or OUT_DIR .]        ;# output directory
set rpt     $out/sta_${corner}.rpt    ;# text report

# --- 1. libraries, netlist, constraints ---
# OpenROAD links against the LEF views
foreach lef [concat [env_or TECH_LEF ""] [env_or CELL_LEF ""] [env_or MACRO_LEFS ""]] {
    read_lef $lef
}
# Liberty files for this corner (cells and macros)
foreach lib [concat $::env(LIBS) [env_or MACRO_LIBS ""]] {
    read_liberty $lib
}
read_verilog $::env(NETLIST)   ;# synthesized netlist
link_design $top               ;# bind instances to library cells

# instances without a Liberty model (untimed black boxes)
set black_boxes {}
foreach inst [get_cells *] {
    if {![get_property $inst is_hierarchical] && [get_property $inst liberty_cell] eq "NULL"} {
        lappend black_boxes "[get_full_name $inst] ([get_property $inst ref_name])"
    }
}

# flip-flop reset/set pins driven directly by ASYNC_RESET_PORT (-1 = not set)
set reset_port [env_or ASYNC_RESET_PORT ""]
set reset_port_pins -1
if {$reset_port ne ""} {
    set reset_port_pins 0
    foreach pin [all_registers -async_pins] {
        set net [get_nets -quiet -of_objects $pin]
        if {$net ne "" && [get_full_name $net] eq $reset_port} { incr reset_port_pins }
    }
}

# platform cell names for the SDC (see docs/writing_sdc.md)
set sb_driving_cell [env_or DRIVING_CELL ""]
set sb_driving_pin  [env_or DRIVING_PIN ""]
set sb_load_cell    [env_or LOAD_CELL ""]
set sb_load_pin     [env_or LOAD_PIN ""]

# input capacitance of one library pin (library units)
proc sb_pin_cap {cell pin} {
    set lib_pin [lindex [get_lib_pins */$cell/$pin] 0]
    if {$lib_pin eq ""} { error "sb_pin_cap: no library pin $cell/$pin" }
    return [get_property $lib_pin capacitance]
}

# SDC period, or the CLOCK_PERIOD override
proc sb_clock_period {default} {
    set p [env_or CLOCK_PERIOD ""]
    if {$p eq ""} { return $default }
    return $p
}

read_sdc $::env(SDC_FILE)   ;# constraints

# --- 2. unconstrained endpoints and loops ---
# check_timing_cmd args: no_input_delay no_output_delay multiple_clock no_clock unconstrained_endpoints loops generated_clocks
set unconstrained 0
foreach err [sta::check_timing_cmd 0 0 0 0 1 0 0] {
    set unconstrained [expr {$unconstrained + [llength [lrange $err 1 end]]}]
}
set loop_errors [llength [sta::check_timing_cmd 0 0 0 0 0 1 0]]

# --- 3. reports (sta_<corner>.rpt) ---
# append a section title to the report
proc section {title} {
    upvar rpt rpt
    set f [open $rpt a]
    puts $f "\n[string repeat = 78]\n$title\n[string repeat = 78]"
    close $f
}
close [open $rpt w]

section "Instances without a timing model (untimed black boxes): [llength $black_boxes]"
set f [open $rpt a]; foreach b $black_boxes { puts $f "  $b" }; close $f
if {$reset_port ne ""} {
    section "Flip-flop reset/set pins driven directly by $reset_port: $reset_port_pins"
}

section "check_setup -verbose  (unconstrained endpoints, missing delays, loops, clocks)"
check_setup -verbose >> $rpt
section "Unconstrained endpoints: $unconstrained"
check_setup -verbose -unconstrained_endpoints >> $rpt

section "Setup (max delay) -- 10 worst paths"
report_checks -path_delay max -group_path_count 10 -fields {slew cap input_pins fanout} -digits 3 >> $rpt
section "Hold (min delay) -- 10 worst paths"
report_checks -path_delay min -group_path_count 10 -fields {slew cap input_pins fanout} -digits 3 >> $rpt

section "Slack summary"
report_wns -digits 3 >> $rpt
report_tns -digits 3 >> $rpt
report_worst_slack -max -digits 3 >> $rpt
report_worst_slack -min -digits 3 >> $rpt

# design-rule checks: reported only, not gating
section "Design rule violators (max slew / max capacitance / max fanout)"
report_check_types -max_slew -max_capacitance -max_fanout -violators >> $rpt

section "Power (static, default activity -- only leakage is meaningful here)"
report_power -digits 6 >> $rpt

# --- 4. summary JSON for ci/checks.py and collect_qor.py ---
set clk_period ""
foreach clk [all_clocks] { set clk_period [get_property $clk period]; break }

lassign [sta::design_power [sta::cmd_scene]] p_int p_sw p_leak p_total

set m [dict create \
    corner          $corner \
    period_ns       $clk_period \
    setup_ws_ns     [sta::worst_slack -max] \
    setup_tns_ns    [sta::total_negative_slack -max] \
    hold_ws_ns      [sta::worst_slack -min] \
    hold_tns_ns     [sta::total_negative_slack -min] \
    seq_cells       [llength [all_registers -cells]] \
    unconstrained_endpoints $unconstrained \
    loop_errors     $loop_errors \
    black_boxes     [llength $black_boxes] \
    reset_port_async_pins $reset_port_pins \
    max_slew_violations        [sta::max_slew_violation_count] \
    max_capacitance_violations [sta::max_capacitance_violation_count] \
    max_fanout_violations      [sta::max_fanout_violation_count] \
    leakage_w       $p_leak \
    total_power_w   $p_total ]

set f [open $out/sta_${corner}.json w]
puts $f "\{"
set keys [dict keys $m]
foreach k $keys {
    set v [dict get $m $k]
    if {![string is double -strict $v]} {
        # non-numbers (INF slack, corner name) as strings
        set v "\"$v\""
    }
    puts -nonewline $f "  \"$k\": $v"
    puts $f [expr {$k eq [lindex $keys end] ? "" : ","}]
}
puts $f "\}"
close $f

puts "SB: corner=$corner period=${clk_period}ns setup_ws=[format %.3f [dict get $m setup_ws_ns]] hold_ws=[format %.3f [dict get $m hold_ws_ns]] unconstrained=$unconstrained[expr {[llength $black_boxes] ? " black_boxes=[llength $black_boxes]" : ""}] -> $rpt"
