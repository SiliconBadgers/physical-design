# File:        place.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Placement: global placement, then place_opt legalizes, fixes slew, capacitance and fanout, and optimizes timing. Writes the icc2/place checkpoint and place.json.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage floorplan place

app_option place.coarse.continue_on_missing_scandef true
app_option place.coarse.max_density $::env(PLACE_DENSITY)   ;# how tightly cells may be packed

# global placement, timing and congestion driven unless switched off
set gpl_args {}
if {[env_or GPL_TIMING_DRIVEN 1]} { lappend gpl_args -timing_driven }
if {[env_or GPL_ROUTABILITY_DRIVEN 1]} { lappend gpl_args -congestion }
create_placement {*}$gpl_args

# legalize and optimize (place_opt without its own first placement)
place_opt -from initial_drc
connect_pg

# congestion estimate from a quick global route
if {[catch {route_global -congestion_map_only true} msg]} { puts "Warning: congestion estimate failed: $msg" }
stage_report place \
    "Legality (overlaps, cells off the rows)" { check_legality } \
    "Congestion"                              { report_congestion }
stage_metrics $OUT/place.json [concat [sb_timing_metrics detailedplace] [sb_area_metrics detailedplace]]
save_stage
