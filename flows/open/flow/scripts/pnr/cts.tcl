# File:        cts.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Clock tree synthesis, then setup and hold repair with real clock arrival times. Writes cts.odb.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load place.odb

set cts_args {-sink_clustering_enable -repair_clock_nets}
if {[env_or CTS_BUF_LIST ""] ne ""} { lappend cts_args -buf_list $::env(CTS_BUF_LIST) }
clock_tree_synthesis {*}$cts_args
set_propagated_clock [all_clocks]

estimate_parasitics -placement
detailed_placement

# setup and hold repair unless switched off
if {![env_or SKIP_CTS_REPAIR_TIMING 0]} {
  repair_timing
  detailed_placement
}
check_placement -verbose

sb_report cts 1
write_db $::env(OUT_DIR)/cts.odb
