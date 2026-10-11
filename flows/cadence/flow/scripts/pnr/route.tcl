# File:        route.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Detailed route (global and detailed, with antenna repair by layer change and diodes), post-route setup and hold repair, and DRC, connectivity and antenna checks. Writes route.db.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open grt
set out $::env(OUT_DIR)

set_db route_design_with_timing_driven true
set_db route_design_with_si_driven true
# antenna repair: layer changes first, then diodes where those are not enough
set_db route_design_antenna_diode_insertion true
set_db route_design_antenna_cell_name $::env(ANTENNA_CELL)
route_design

# setup and hold repair with real wires
opt_design -post_route -setup -hold

# checks: DRC (counted now, before other checks add markers), opens and shorts, antennas
sb_try check_drc -out_file $out/route_drc.rpt
set drc_errors [sb_drc_count $out/route_drc.rpt]
sb_try check_connectivity -out_file $out/route_connectivity.rpt
sb_try check_process_antenna -out_file $out/route_antenna.rpt

sb_report route detailedroute -post_route
sb_write_json $out/route.json [list \
    detailedroute__route__wirelength [sb_value { tcl::mathop::+ 0 {*}[get_db nets .wires.length] }] \
    detailedroute__route__vias       [sb_value { llength [get_db nets .vias] }] \
    detailedroute__route__drc_errors $drc_errors]
puts "SB: route drc_errors=$drc_errors -> $out/route_drc.rpt"

sb_save route
sb_done route
exit
