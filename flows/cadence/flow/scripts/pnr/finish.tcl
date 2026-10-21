# File:        finish.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Fill cells, Quantus extraction and the final outputs: finish.db, final.v (timing), final_logic.v (LEC, GLS), final_lvs.v (LVS), final.def and one SPEF per corner.
#              make then runs Tempus (sign-off timing) and Voltus (IR drop) on them.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open route
set out $::env(OUT_DIR)

# fill empty sites: decoupling-capacitor fillers first, only where their met1 pins clear the routed wires
# (add_fillers_with_drc false: no second pass without DRC checks), then plain fillers (rails only) in every gap left
set_db add_fillers_cells $::env(DECAP_CELLS)
set_db add_fillers_with_drc false
add_fillers
set_db add_fillers_with_drc true
set_db add_fillers_cells $::env(FILL_CELLS)
add_fillers
sb_connect_pg   ;# power pins of every cell added after the floorplan
sb_try check_place $out/finish_check_place.rpt
sb_try check_drc -out_file $out/finish_drc.rpt

# extraction: wire R and C of every net (EXTRACT_EFFORT=signoff runs standalone Quantus)
# at every corner (Tempus, Voltus and the abstract read all three SPEFs): extract_rc only extracts the RC corners of active views
proc sb_views {corners} { lmap c $corners { string cat view_ $c } }
set_analysis_view -setup [sb_views {ss tt ff}] -hold [sb_views {ss tt ff}] -leakage view_tt -dynamic view_tt
set_db extract_rc_engine post_route
set_db extract_rc_effort_level $::env(EXTRACT_EFFORT)
set_db extract_rc_coupled true
extract_rc
foreach c {ss tt ff} {
    write_parasitics -spef_file $out/final_$c.spef -rc_corner rc_$c
}
set_analysis_view -setup [sb_views $::env(SETUP_CORNERS)] -hold [sb_views $::env(HOLD_CORNERS)] -leakage view_tt -dynamic view_tt

# netlists: for timing (with the clock tree), logic only for LEC and GLS (no physical-only cells, power pins or cell definitions),
# and for LVS (power pins and physical cells, no plain fillers)
write_netlist $out/final.v
write_netlist $out/final_logic.v -exclude_leaf_cells -exclude_insts_of_cells $::env(PHYSICAL_CELLS)
write_netlist $out/final_lvs.v -top_module_first -top_module $::env(TOP) \
    -exclude_leaf_cells -phys -flat -exclude_insts_of_cells $::env(FILL_CELLS)
sb_try write_def $out/final.def

# area numbers; finish timing comes from Tempus with the SPEF
sb_try report_area > $out/finish.rpt
if {[catch {sb_area} a]} {
    puts "SB-WARNING: area numbers failed: $a"
    set a {null null null null null}
}
lassign $a area count util core die
sb_write_json $out/finish.json [list \
    finish__design__instance__area        $area \
    finish__design__instance__count       $count \
    finish__design__instance__utilization $util \
    finish__design__core__area            $core \
    finish__design__die__area             $die \
    finish__route__drc_errors             [sb_drc_count $out/finish_drc.rpt]]
puts "SB: finish area=$area util=$util -> $out/finish.rpt"

sb_save finish
sb_done finish
exit
