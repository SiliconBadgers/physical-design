# File:        route.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Detailed route along the global-route guides, with antenna repair. Writes route.odb and route_drc.rpt.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load grt.odb
set_propagated_clock [all_clocks]
source $::env(FASTROUTE_TCL)   ;# routing layers

utl::push_metrics_stage "detailedroute__{}"
set drt_args [list -output_drc $::env(OUT_DIR)/route_drc.rpt -verbose 1]
detailed_route {*}$drt_args
# antennas left after routing: add diodes and reroute, up to 3 times
for {set i 0} {$i < 3 && [check_antennas]} {incr i} {
  repair_antennas -diode_only
  detailed_route {*}$drt_args
}
check_antennas -report_file $::env(OUT_DIR)/antennas.rpt
utl::pop_metrics_stage

write_db $::env(OUT_DIR)/route.odb
