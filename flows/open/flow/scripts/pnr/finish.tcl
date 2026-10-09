# File:        finish.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Fill cells and final outputs, then parasitic extraction, sign-off timing and IR drop. Writes final.odb, .def, .v, .cdl and .spef.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load route.odb
set_propagated_clock [all_clocks]

filler_placement $::env(FILL_CELLS)
check_placement -verbose
# power pins of cells added after the floorplan (buffers, clock tree, diodes, fill)
global_connect

# write the layout before extraction: extract_parasitics drops the router's min-area patches
write_db $::env(OUT_DIR)/final.odb
write_def $::env(OUT_DIR)/final.def
write_verilog $::env(OUT_DIR)/final.v
write_cdl -masters [concat $::env(CDL_FILE) [env_or MACRO_CDL ""]] $::env(OUT_DIR)/final.cdl   ;# netlist for LVS

# extracted wire RC replaces the estimates
define_process_corner -ext_model_index 0 X
set_extraction_rules_file $::env(RCX_RULES)
extract_parasitics
write_spef $::env(OUT_DIR)/final.spef
read_spef $::env(OUT_DIR)/final.spef

sb_report finish 1
report_power > $::env(OUT_DIR)/power.rpt

# static IR drop on both supply nets
foreach {net volt} [list $::env(PWR_NET) $::env(VDD_V) $::env(GND_NET) 0.0] {
  set_pdnsim_net_voltage -net $net -voltage $volt
  analyze_power_grid -net $net -error_file $::env(OUT_DIR)/ir_$net.rpt
}
