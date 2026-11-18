# File:        common.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Shared procs for the Innovus (Stylus) place-and-route scripts: load and save a stage database, and report a stage.
#              Inputs are environment variables from pnr.env, written by make.
source $::env(SCRIPTS)/util/sb_util.tcl

set_multi_cpu_usage -local_cpu [env_or NCPU 4]
set_db design_process_node 130

# Innovus 21.x: some options are spelled otherwise there (write_stream -unit, write_lef_abstract -top_layer); chosen by release,
# not by trying, because a failed try leaves an error line in the log and make fails the stage on it
proc sb_innovus21 {} { expr {[get_db program_major_version] < 22} }

# settings every Innovus session needs, also after read_db
proc sb_settings {} {
    set_db timing_analysis_type ocv     ;# early/late analysis on every path
    set_db timing_analysis_cppr both    ;# remove common clock path pessimism
    set_db design_bottom_routing_layer $::env(MIN_ROUTING_LAYER)
    set_db design_top_routing_layer $::env(MAX_ROUTING_LAYER)
    set_db extract_rc_lef_tech_file_map $::env(QRC_LAYER_MAP)   ;# LEF and Quantus layer names differ
}

# cell power pins (library pins VDD/VSS) to the supply nets; again after cells are added
proc sb_connect_pg {} {
    connect_global_net $::env(PWR_NET) -type pg_pin -pin_base_name VDD -all
    connect_global_net $::env(GND_NET) -type pg_pin -pin_base_name VSS -all
}

# new design from the synthesis netlist (floorplan stage)
proc sb_init_design {} {
    read_mmmc $::env(SCRIPTS)/mmmc.tcl
    read_physical -lef [concat $::env(TECH_LEF) $::env(CELL_LEF) [env_or MACRO_LEFS ""]]
    read_netlist $::env(NETLIST) -top $::env(TOP)
    set_db init_power_nets $::env(PWR_NET)
    set_db init_ground_nets $::env(GND_NET)
    init_design
    sb_settings
    sb_connect_pg
}

# instances of the hard macros (cells named in MACROS)
proc sb_macro_insts {} {
    set insts {}
    foreach cell [env_or MACROS ""] {
        foreach inst [get_db insts -if ".base_cell.name == $cell"] { lappend insts $inst }
    }
    return $insts
}

# stage database: <stage>.db in the build directory
proc sb_open {stage} {
    read_db $::env(OUT_DIR)/$stage.db
    sb_settings
}
proc sb_save {stage} {
    file delete -force $::env(OUT_DIR)/$stage.db
    write_db $::env(OUT_DIR)/$stage.db
}

# clocks propagated (real clock tree arrival times) in every active constraint mode
proc sb_propagate {} {
    sb_try set_interactive_constraint_modes [get_db constraint_modes .name]
    sb_try set_propagated_clock [all_clocks]
    sb_try set_interactive_constraint_modes {}
}

# area numbers {instance area, instance count, utilization, core area, die area}; filler cells are left out
proc sb_area {} {
    set fillers [concat $::env(FILL_CELLS) $::env(DECAP_CELLS)]
    set area 0.0
    set count 0
    foreach cell [get_db insts .base_cell.name] a [get_db insts .area] {
        if {[lsearch -exact $fillers $cell] < 0} {
            set area [expr {$area + $a}]
            incr count
        }
    }
    lassign [join [get_db designs .core_bbox]] x1 y1 x2 y2
    set core [expr {($x2 - $x1) * ($y2 - $y1)}]
    lassign [join [get_db designs .bbox]] x1 y1 x2 y2
    set die [expr {($x2 - $x1) * ($y2 - $y1)}]
    set util [expr {$core > 0 ? $area / $core : "null"}]
    return [list $area $count $util $core $die]
}

# one number from a time_design summary (plain or gzipped), or null
proc sb_summary {dir prefix pattern} {
    set files [glob -nocomplain $dir/$prefix.summary*]
    if {$files eq "" || [catch {exec gzip -dcf [lindex $files 0]} text]} { return null }
    if {[regexp $pattern $text -> value]} { return $value }
    return null
}

# DRC violations from a check_drc report, else the markers in the database
proc sb_drc_count {rpt} {
    if {![catch {open $rpt} fh]} {
        set text [read $fh]
        close $fh
        if {[regexp {Total Violations\s*:\s*([0-9]+)} $text -> n]} { return $n }
        if {[regexp -nocase {No DRC violations} $text]} { return 0 }
    }
    return [sb_value { llength [get_db markers] }]
}

# timing, area (and clock skew) of a stage: <stage>.rpt, Innovus summaries in reports/<stage>/, metrics in <stage>.json.
# key: ORFS stage name of the metrics; mode: time_design mode (-pre_cts, -post_cts, -post_route) or "" for none
proc sb_report {stage key mode {skew 0}} {
    set out $::env(OUT_DIR)
    set rpt $out/$stage.rpt
    set dir $out/reports/$stage
    file mkdir $dir
    if {$mode ne ""} {
        sb_try time_design $mode -report_dir $dir -report_prefix $stage
        sb_try time_design $mode -hold -report_dir $dir -report_prefix ${stage}_hold
    }
    sb_try report_area > $rpt
    sb_try report_timing -late  -max_paths 10 >> $rpt
    sb_try report_timing -early -max_paths 10 >> $rpt
    if {$skew} { sb_try report_clock_timing -type skew >> $rpt }

    lassign [sb_slack -late]  setup_ws setup_tns
    lassign [sb_slack -early] hold_ws hold_tns
    # what report_timing could not give: from the time_design summaries
    set wns {WNS \(ns\):\s*\|\s*(-?[0-9.]+)}
    set tns {TNS \(ns\):\s*\|\s*(-?[0-9.]+)}
    if {$setup_ws eq "null"}  { set setup_ws  [sb_summary $dir $stage $wns] }
    if {$setup_tns eq "null"} { set setup_tns [sb_summary $dir $stage $tns] }
    if {$hold_ws eq "null"}   { set hold_ws   [sb_summary $dir ${stage}_hold $wns] }
    if {$hold_tns eq "null"}  { set hold_tns  [sb_summary $dir ${stage}_hold $tns] }

    if {[catch {sb_area} a]} {
        puts "SB-WARNING: area numbers failed: $a"
        set a {null null null null null}
    }
    lassign $a area count util core die
    set pairs [list \
        ${key}__timing__setup__ws          $setup_ws \
        ${key}__timing__setup__tns         $setup_tns \
        ${key}__timing__hold__ws           $hold_ws \
        ${key}__timing__hold__tns          $hold_tns \
        ${key}__design__instance__area     $area \
        ${key}__design__instance__count    $count \
        ${key}__design__instance__utilization $util \
        ${key}__design__core__area         $core \
        ${key}__design__die__area          $die]
    if {$skew} {
        lassign [sb_skew] skew_setup skew_hold
        lappend pairs ${key}__clock__skew__setup $skew_setup ${key}__clock__skew__hold $skew_hold
    }
    sb_write_json $out/$stage.json $pairs
    puts "SB: $stage setup_ws=$setup_ws hold_ws=$hold_ws area=$area util=$util -> $rpt"
}
