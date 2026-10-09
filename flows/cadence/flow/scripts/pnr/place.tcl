# File:        place.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Placement: pins, global and detailed placement, then electrical and setup repair (place_opt_design) and tie cells. Writes place.db.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open floorplan
set out $::env(OUT_DIR)

set_db place_global_max_density $::env(PLACE_DENSITY)
set_db place_global_timing_driven [expr {$::env(GPL_TIMING_DRIVEN) ? "true" : "false"}]
set_db place_global_place_io_pins true   ;# pins not placed in floorplan go next to their logic

# placement, then slew, capacitance, fanout and setup repair, then legalization
place_opt_design

# tie cells for any constant synthesis left
sb_try set_db add_tieoffs_cells [list $::env(TIEHI_CELL) $::env(TIELO_CELL)]
sb_try add_tieoffs
sb_try check_place $out/place_check.rpt

sb_report place detailedplace -pre_cts
sb_save place
sb_done place
exit
