# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Floorplan: core size, routing tracks, macro placement, tap cells and power grid. Writes floorplan.odb.
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

# hard macros: placed by the macro placer with a keep-out ring and channels between them
if {[env_or MACRO_LEFS ""] ne ""} {
  file mkdir $::env(OUT_DIR)/rtlmp
  set_halo -halo $::env(MACRO_HALO) -apply_to_all_macros
  rtl_macro_placer -min_channel_size $::env(MACRO_CHANNEL) -pin_aware_channels \
    -target_util $::env(PLACE_DENSITY) -report_directory $::env(OUT_DIR)/rtlmp
}

set ::env(TAP_CELL_NAME) $::env(TAP_CELL)   ;# name the platform tapcell.tcl expects
source $::env(TAPCELL_TCL)

source $::env(PDN_TCL)   ;# grid definition
pdngen

sb_report floorplan
write_db $::env(OUT_DIR)/floorplan.odb
