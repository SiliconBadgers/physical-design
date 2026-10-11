# File:        route.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Detailed route along the global routes, with antenna repair, then route_opt. Writes the icc2/route checkpoint, route_drc.rpt and route.json.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage grt route

app_option route.track.timing_driven true
app_option route.detail.timing_driven true

# antenna rules (antenna.tcl); the router fixes violations with layer jumps or diodes
if {[catch {source -echo $::env(SCRIPTS)/icc2/antenna.tcl} msg]} {
    sb_note "warning: antenna rules not loaded, antenna check is off: $msg"
}
app_option route.detail.antenna true
app_option route.detail.insert_diodes_during_routing true
app_option route.detail.diode_libcell_names $::env(DIODE_CELL)   ;# the cell name without the library name

# track assignment and detailed route (violations per iteration are in the log), then timing repair
route_track
route_detail
route_opt
connect_pg

# routing DRC, open nets and antenna summary
sb_report $OUT/route_drc.rpt { check_routes }
stage_report route
stage_metrics $OUT/route.json [sb_route_metrics detailedroute $OUT/route_drc.rpt]
save_stage
