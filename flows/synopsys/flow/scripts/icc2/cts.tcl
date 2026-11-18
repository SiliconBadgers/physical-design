# File:        cts.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Clock tree synthesis with the CTS_BUF_LIST cells, then setup and hold repair with real clock arrival times. Writes the icc2/cts checkpoint and cts.json.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage place cts

# clock wires on MIN_CLK_ROUTING_LAYER and above (thicker, less resistance)
set_clock_routing_rules -default_rule -min_routing_layer $::env(MIN_CLK_ROUTING_LAYER) -max_routing_layer $::env(MAX_ROUTING_LAYER)

# build and route the clock tree
clock_opt -to route_clock
connect_pg

# setup and hold repair unless switched off
if {![env_or SKIP_CTS_REPAIR_TIMING 0]} {
    clock_opt -from final_opto
    connect_pg
}

stage_report cts \
    "Clock tree QoR" { report_clock_qor } \
    "Clock skew"     { report_clock_timing -type skew }
stage_metrics $OUT/cts.json [concat [sb_timing_metrics cts] [sb_area_metrics cts] \
    [list cts__clock__skew__setup [sb_try { sb_clock_skew }]]]
save_stage
