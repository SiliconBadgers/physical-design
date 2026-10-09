# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Floorplan: design library from the netlist, corners, core size, tap cells, power grid and pins. Writes the icc2/floorplan checkpoint and floorplan.json.
source $::env(SCRIPTS)/icc2/common.tcl

# --- design library and netlist ---
set lib [stage_lib floorplan]
file delete -force [file dirname $lib]
file mkdir [file dirname $lib]
create_lib $lib -technology $::env(TECH_FILE) -ref_libs $::env(CELL_NDM)
read_verilog -top $TOP $::env(NETLIST)
link_block
tech_rules
lib_cell_rules
power_intent
setup_scenarios

# core from the target utilization; the die adds CORE_MARGIN on each side
initialize_floorplan -shape R -core_utilization [expr {$::env(CORE_UTILIZATION) / 100.0}] \
    -side_ratio [list 1 $::env(ASPECT_RATIO)] -core_offset $::env(CORE_MARGIN)

# tap cells tie the wells to VDD and VSS, every 14 um along each row
create_tap_cells -lib_cell [get_lib_cells */$::env(TAP_CELL)] -distance 14 -pattern stagger -skip_fixed_cells
connect_pg

source -echo $::env(PDN_TCL)   ;# power grid

# pins on the core edge, on the pin layers
set_block_pin_constraints -self -allowed_layers [list $::env(IO_V_LAYER) $::env(IO_H_LAYER)]
if {[env_or IO_CONSTRAINTS ""] ne ""} { source -echo $::env(IO_CONSTRAINTS) }
place_pins -self

stage_report floorplan \
    "Power grid connectivity" { check_pg_connectivity -check_std_cell_pins none } \
    "Power grid DRC"          { check_pg_drc -ignore_std_cells } \
    "Pins"                    { report_pin_placement -self }
stage_metrics $OUT/floorplan.json [concat [sb_timing_metrics floorplan] [sb_area_metrics floorplan]]
save_stage
