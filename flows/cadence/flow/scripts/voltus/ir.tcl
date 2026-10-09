# File:        ir.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Voltus static IR drop of the finished block: average power at tt, then the voltage drop across the VDD/VSS grid. Results in ir/.
source $::env(SCRIPTS)/util/sb_util.tcl
set out $::env(OUT_DIR)
set dir $out/ir
set_multi_cpu_usage -local_cpu [env_or NCPU 4]

read_db $out/finish.db
foreach c {ss tt ff} { read_spef -rc_corner rc_$c $out/final_$c.spef }

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
set_power_data -format current [list $dir/power/static_$pwr.ptiavg $dir/power/static_$gnd.ptiavg]
report_rail -output_dir $dir/rail -type domain ALL
puts "SB: ir reports in $dir/rail"

sb_done ir
exit
