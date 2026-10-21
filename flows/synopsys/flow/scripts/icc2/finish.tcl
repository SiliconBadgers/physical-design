# File:        finish.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Fill cells and the outputs for sign-off: final.v (timing), final_logic.v (LEC and GLS), final_lvs.v (LVS), final.def (extraction). Writes the icc2/finish checkpoint and finish.json; the sign-off slack is added after PrimeTime.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage route finish

# fill the empty sites, biggest filler first, so rails and wells stay continuous
set fillers {}
foreach c $::env(FILL_CELLS) { lappend fillers */$c }
create_stdcell_fillers -lib_cells [get_object_name [sort_collection -descending [get_lib_cells $fillers] area]]
connect_pg
remove_stdcell_fillers_with_violation

# netlist for PrimeTime: no power pins, no physical-only cells
set no_physical {scalar_wire_declarations leaf_module_declarations end_cap_cells well_tap_cells filler_cells pad_spacer_cells physical_only_cells cover_cells supply_statements pg_netlist}
write_verilog -exclude $no_physical -hierarchy all $OUT/final.v
# logic netlist for LEC and GLS: also no antenna diodes
if {[catch {write_verilog -exclude [concat $no_physical diode_cells] -hierarchy all $OUT/final_logic.v} msg]} {
    sb_note "warning: final_logic.v keeps the antenna diodes: $msg"
    file copy -force $OUT/final.v $OUT/final_logic.v
}
# netlist for LVS: with power pins and every physical cell
write_verilog -exclude {scalar_wire_declarations leaf_module_declarations empty_modules} \
    -hierarchy all $OUT/final_lvs.v
write_def $OUT/final.def   ;# placement and wires for StarRC (and GDS_TOOL=klayout)

stage_report finish \
    "Routing DRC and open nets" { check_routes } \
    "Power grid connectivity"   { check_pg_connectivity }
stage_metrics $OUT/finish.json [concat [sb_area_metrics finish] \
    [list finish__timing__setup__ws "" finish__timing__setup__tns "" finish__timing__hold__ws "" finish__timing__hold__tns ""]]
save_stage
