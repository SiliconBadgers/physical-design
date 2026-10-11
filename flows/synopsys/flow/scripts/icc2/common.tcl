# File:        common.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: IC Compiler II settings and procs shared by every stage: checkpoints, technology and cell rules, power nets, scenarios, reports and metrics. Inputs are environment variables from pnr.env, written by the Makefile.

source $::env(SCRIPTS)/util/metrics.tcl

set TOP           $::env(TOP)
set OUT           $::env(OUT_DIR)
set CORNERS       $::env(CORNERS)         ;# one scenario per corner
set SETUP_CORNERS $::env(SETUP_CORNERS)   ;# corners checked and fixed for setup
set HOLD_CORNERS  $::env(HOLD_CORNERS)    ;# corners checked and fixed for hold
set_host_options -max_cores [env_or CORES 4]

# --- checkpoints: each stage keeps its own copy of the design library ---
# icc2/<stage>/<top>.nlib in the build folder
proc stage_lib {stage} { return $::OUT/icc2/$stage/$::TOP.nlib }

# copy the checkpoint of stage $from to stage $to, then open it
proc open_stage {from to} {
    set src [stage_lib $from]
    set dst [stage_lib $to]
    if {![file exists $src]} { error "no checkpoint $src: run make $from first" }
    file delete -force [file dirname $dst]
    file mkdir [file dirname $dst]
    file copy $src $dst
    open_lib $dst
    open_block $::TOP
    link_block
    lib_cell_rules
}

proc save_stage {} {
    save_block
    save_lib
}

# set an app option; a name this version does not know is a warning, not a stop
proc app_option {name value} {
    if {[catch {set_app_options -name $name -value $value} msg]} {
        sb_note "warning: app option $name not set: $msg"
    }
}

# --- technology rules missing from the .tf file (values from the sky130 tech LEF) ---
proc tech_rules {} {
    foreach {layer dir offset} {
        li1  vertical   0.23
        met1 horizontal 0.17
        met2 vertical   0.23
        met3 horizontal 0.34
        met4 vertical   0.46
        met5 horizontal 1.70
    } {
        set_attribute [get_layers $layer] routing_direction $dir   ;# preferred wire direction
        set_attribute [get_layers $layer] track_offset $offset     ;# first routing track (um)
    }
    # row site: the cells' site, one row tall (0.46 x 2.72 um)
    set site [env_or SITE auto]
    if {$site eq "auto"} {
        set site [expr {[sizeof_collection [get_site_defs -quiet unithd]] ? "unithd" : "unit"}]
    }
    set_attribute [get_site_defs] is_default false
    set_attribute [get_site_defs $site] is_default true
    set_attribute [get_site_defs $site] symmetry Y
    sb_note "rows use site $site"
    # signal routing layers; li1 stays inside the cells
    set_ignored_layers -min_routing_layer $::env(MIN_ROUTING_LAYER) -max_routing_layer $::env(MAX_ROUTING_LAYER)
    app_option route.common.global_min_layer_mode hard
    app_option route.common.global_max_layer_mode hard
}

# --- library cells: cells to avoid, cells the clock tree may use ---
proc lib_cell_rules {} {
    foreach pattern $::env(PNR_DONT_USE) {
        set cells [get_lib_cells -quiet */$pattern]
        if {[sizeof_collection $cells] && [catch {set_dont_use $cells}]} {
            set_attribute $cells dont_use true
        }
    }
    set cts_cells {}
    foreach c [env_or CTS_BUF_LIST ""] { lappend cts_cells */$c }
    if {[llength $cts_cells]} {
        set_lib_cell_purpose -exclude cts [get_lib_cells */*]
        set_lib_cell_purpose -include cts [get_lib_cells $cts_cells]
    }
}

# --- power: one domain with supplies VDD and VSS (power.upf) ---
proc power_intent {} {
    load_upf $::env(SCRIPTS)/icc2/power.upf
    commit_upf
    connect_pg
}

# connect every cell's power pins to VDD and VSS; run again after cells are added
proc connect_pg {} {
    connect_pg_net -automatic
    foreach {net pins} {VDD {VPWR VPB VDD} VSS {VGND VNB VSS}} {
        foreach pin $pins {
            set pg [get_pins -quiet -hierarchical */$pin]
            if {[sizeof_collection $pg]} { connect_pg_net -net $net $pg }
        }
    }
}

# --- scenarios: one mode (func) at each corner; setup and hold on the sign-off corners ---
proc sb_bool {cond} { return [expr {$cond ? "true" : "false"}] }

# PNR_SETUP_MARGIN: add setup uncertainty to each clock of the current scenario, on top of the SDC's (simple uncertainty only,
# not -from/-to), so place and route leave that much slack for the sign-off extraction and delay calculation
proc pnr_setup_margin {} {
    set margin [env_or PNR_SETUP_MARGIN 0]
    if {$margin == 0} { return }
    foreach_in_collection clk [all_clocks] {
        set sdc [get_attribute -quiet $clk setup_uncertainty]
        if {$sdc eq ""} { set sdc 0.0 }
        set_clock_uncertainty -setup [expr {$sdc + $margin}] $clk
        sb_note "[get_object_name [current_scenario]]: [get_object_name $clk] setup uncertainty [format %.3f $sdc] + $margin ns (PNR_SETUP_MARGIN)"
    }
}

proc setup_scenarios {} {
    remove_modes -all
    remove_corners -all
    remove_scenarios -all
    read_parasitic_tech -tlup $::env(TLUPLUS) -name nominal   ;# one RC table for all corners
    create_mode func
    foreach c $::CORNERS {
        create_corner $c
        create_scenario -name func_$c -mode func -corner $c
    }
    foreach c $::CORNERS {
        current_scenario func_$c
        set_parasitic_parameters -early_spec nominal -late_spec nominal
        set_process_number 1.0
        set_voltage $::env(VOLT_$c) -object_list [get_supply_nets VDD]
        set_voltage 0.0 -object_list [get_supply_nets VSS]
        set_temperature $::env(TEMP_$c)
        source -echo $::env(SDC_FILE)   ;# not read_sdc: it rejects non-SDC commands such as remove_from_collection
        pnr_setup_margin
        set_scenario_status func_$c -active true \
            -setup [sb_bool [expr {$c in $::SETUP_CORNERS}]] \
            -hold  [sb_bool [expr {$c in $::HOLD_CORNERS}]] \
            -leakage_power [sb_bool [expr {$c eq "tt"}]] -dynamic_power [sb_bool [expr {$c eq "tt"}]] \
            -max_transition true -max_capacitance true
    }
    current_scenario func_[lindex $::SETUP_CORNERS 0]
    sb_report $::OUT/scenarios.rpt { report_scenarios }
}

# --- reports: <stage>.rpt with the QoR summary, utilization and the worst setup and hold paths ---
proc stage_report {stage args} {
    set rpt $::OUT/$stage.rpt
    close [open $rpt w]
    sb_section $rpt "QoR summary" { report_qor -summary }
    sb_section $rpt "Utilization" { report_utilization }
    sb_section $rpt "Setup: 10 worst paths" { report_timing -delay_type max -max_paths 10 -nosplit -input_pins -nets }
    sb_section $rpt "Hold: 10 worst paths" { report_timing -delay_type min -max_paths 10 -nosplit -input_pins -nets }
    foreach {title script} $args { sb_section $rpt $title $script }
}

# --- metrics, under the ORFS stage names (floorplan, detailedplace, cts, globalroute, detailedroute, finish) ---
# area of a polygon given as {{x y} ...} (um2)
proc sb_polygon_area {points} {
    set sum 0.0
    set n [llength $points]
    for {set i 0} {$i < $n} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {($i + 1) % $n}]] x2 y2
        set sum [expr {$sum + $x1 * $y2 - $x2 * $y1}]
    }
    return [expr {abs($sum) / 2.0}]
}

# area of every placed cell except fillers (um2): standard cells, tap cells and macros
proc sb_instance_area {} {
    set area 0.0
    foreach_in_collection cell [get_cells -hierarchical -filter "is_hierarchical==false"] {
        set ref [get_attribute $cell ref_name]
        if {[lsearch -exact $::env(FILL_CELLS) $ref] < 0} { set area [expr {$area + [get_attribute $cell area]}] }
    }
    return $area
}

# core area, instance area and utilization
proc sb_area_metrics {stage} {
    set core [sb_try { sb_polygon_area [get_attribute [get_core_area] boundary] }]
    set inst [sb_try { sb_instance_area }]
    set util [sb_try { expr {$inst / $core} }]
    return [list ${stage}__design__core__area $core ${stage}__design__instance__area $inst \
                 ${stage}__design__instance__utilization $util]
}

# worst and total negative slack of the setup and hold scenarios
proc sb_timing_metrics {stage} {
    set setup [sb_try { sb_failing max }]
    set hold  [sb_try { sb_failing min }]
    return [list ${stage}__timing__setup__ws [sb_try { sb_worst_slack max }] ${stage}__timing__setup__tns [lindex $setup 1] \
                 ${stage}__timing__hold__ws [sb_try { sb_worst_slack min }] ${stage}__timing__hold__tns [lindex $hold 1]]
}

# clock skew (ns): largest launch and capture clock latency difference on the worst register-to-register setup paths
proc sb_clock_skew {} {
    set skew ""
    # only register-to-register paths: in sb_sram_256x8 the 1000 worst paths all start at input ports
    foreach_in_collection path [get_timing_paths -delay_type max -max_paths 1000 -from [all_registers] -to [all_registers]] {
        if {[get_attribute [get_attribute $path startpoint] object_class] ne "pin"} { continue }
        if {[get_attribute [get_attribute $path endpoint] object_class] ne "pin"} { continue }
        set d [expr {abs([get_attribute $path startpoint_clock_latency] - [get_attribute $path endpoint_clock_latency])}]
        if {$skew eq "" || $d > $skew} { set skew $d }
    }
    return $skew
}

# write a stage's metrics JSON and print them on one summary line
proc stage_metrics {file pairs} {
    sb_json $file $pairs
    set items {}
    foreach {key value} $pairs {
        regsub {^[a-z]+__} $key "" key
        set value [sb_json_value $value]
        if {$value ne "null"} { set value [format %.4g $value] }
        lappend items "$key=$value"
    }
    sb_note "[file tail $file]: [join $items {, }]"
}

# wire length (um), via count and DRC count from a check_routes report
proc sb_route_metrics {stage file} {
    set wl ""; set vias ""; set drc ""; set text ""
    if {[file exists $file]} {
        set fh [open $file]
        set text [read $fh]
        close $fh
    }
    regexp {Total Wire Length\s*=\s*([0-9.]+)} $text -> wl
    regexp {Total Number of Contacts\s*=\s*([0-9]+)} $text -> vias
    if {![regexp {Total number of DRCs\s*=\s*([0-9]+)} $text -> drc]} {
        regexp {TOTAL VIOLATIONS\s*=\s*([0-9]+)} $text -> drc
    }
    return [list ${stage}__route__wirelength $wl ${stage}__route__vias $vias ${stage}__route__drc_errors $drc]
}
