# File:        grt.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Global route: which routing cells each net crosses, with timing on the global-route wires. Writes the icc2/grt checkpoint, congestion.rpt and grt.json.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage cts grt

app_option route.global.timing_driven true
route_global
sb_report $OUT/congestion.rpt { report_congestion }

stage_report grt
stage_metrics $OUT/grt.json [concat [sb_timing_metrics globalroute] [sb_area_metrics globalroute]]
save_stage
