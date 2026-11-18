# File:        ir.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Voltus static IR drop of the finished block: average power at tt, then the voltage drop across the VDD/VSS grid. Results in ir/.
source $::env(SCRIPTS)/util/sb_util.tcl
set out $::env(OUT_DIR)
set dir $out/ir
set_multi_cpu_usage -local_cpu [env_or NCPU 4]

read_db $out/finish.db
# SPEF of each active corner (read_spef rejects an RC corner no active view uses)
foreach c [lsort -unique [concat $::env(SETUP_CORNERS) $::env(HOLD_CORNERS) tt]] { read_spef -rc_corner rc_$c $out/final_$c.spef }

# voltage sources: the VDD/VSS pins where the met5 straps meet the die edge
set pwr $::env(PWR_NET)
set gnd $::env(GND_NET)
set_power_pads -net $pwr -format defpin
set_power_pads -net $gnd -format defpin

# static (average) power per cell at the typical corner, default switching activity
set_db power_method static
set_db power_write_static_currents true
set_db power_write_db true
report_power -view view_tt -out_dir $dir/power

# rail analysis: the grid as a resistor network driven by those currents
set_rail_analysis_config -method static -accuracy xd -analysis_view view_tt \
    -power_grid_libraries [list $::env(PGV_DIR)/techonly.cl]
# net voltages and pass limits (5% of VDD); after set_rail_analysis_config, which resets them
set_pg_nets -net $pwr -voltage $::env(VDD_V) -threshold [expr {0.95 * $::env(VDD_V)}]
set_pg_nets -net $gnd -voltage 0 -threshold [expr {0.05 * $::env(VDD_V)}]
set_power_data -format current [list $dir/power/static_$pwr.ptiavg $dir/power/static_$gnd.ptiavg]
# one analysis per net (-type domain ALL needs domains from CPF or set_rail_analysis_domain); Voltus does not stop on a failed
# analysis, so each net must leave its results.json; worst drop: lowest VDD node, highest VSS node
file delete -force $dir/rail
foreach net [list $pwr $gnd] {
    report_rail -type net -output_dir $dir/rail $net
    set res [lindex [glob -nocomplain $dir/rail/${net}_*/results.json] 0]
    if {$res eq ""} { error "no rail analysis results for $net in $dir/rail" }
    set fh [open $res]
    set text [read $fh]
    close $fh
    regexp {"min_node_voltage":\s*"([^"]+)"} $text -> vmin
    regexp {"max_node_voltage":\s*"([^"]+)"} $text -> vmax
    set drop [expr {$net eq $pwr ? $::env(VDD_V) - $vmin : $vmax}]
    puts [format "SB: ir %s worst static drop %.3f mV (%s)" $net [expr {1000.0 * $drop}] [file dirname $res]]
}

sb_done ir
exit
