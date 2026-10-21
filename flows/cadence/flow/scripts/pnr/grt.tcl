# File:        grt.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Global route (Innovus early global route): congestion map and wire estimates for timing. Writes grt.db; route_design in route.tcl routes again in full.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open cts
set out $::env(OUT_DIR)

route_early_global
sb_try report_congestion -hotspot > $out/grt_congestion.rpt

sb_report grt globalroute -post_cts
sb_save grt
sb_done grt
exit
