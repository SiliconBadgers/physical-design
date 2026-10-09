# File:        grt.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Global route and antenna repair. Writes grt.odb with the route guides.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load cts.odb
set_propagated_clock [all_clocks]

# layer limits and per-layer capacity reduction from the platform
source $::env(FASTROUTE_TCL)
global_route -congestion_iterations 30 -congestion_report_file $::env(OUT_DIR)/congestion.rpt

# diodes (not layer jumpers) on nets whose gates see too much metal
repair_antennas -diode_only -iterations 5
check_placement -verbose

estimate_parasitics -global_routing
sb_report globalroute
write_db $::env(OUT_DIR)/grt.odb
