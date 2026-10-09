# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Floorplan: core size, routing tracks, tap cells and power grid. Writes floorplan.odb.
source $::env(SCRIPTS)/pnr/common.tcl

foreach lef [concat $::env(TECH_LEF) $::env(CELL_LEF) [env_or MACRO_LEFS ""]] { read_lef $lef }
sb_read_libs
read_verilog $::env(NETLIST)
link_design $::env(TOP)
sb_setup

# core from the target utilization; the die adds CORE_MARGIN on each side
initialize_floorplan -utilization $::env(CORE_UTILIZATION) -aspect_ratio $::env(ASPECT_RATIO) \
  -core_space $::env(CORE_MARGIN) -site $::env(SITE)
source $::env(MAKE_TRACKS_TCL)

set ::env(TAP_CELL_NAME) $::env(TAP_CELL)   ;# name the platform tapcell.tcl expects
source $::env(TAPCELL_TCL)

source $::env(PDN_TCL)   ;# grid definition
pdngen

sb_report floorplan
write_db $::env(OUT_DIR)/floorplan.odb
