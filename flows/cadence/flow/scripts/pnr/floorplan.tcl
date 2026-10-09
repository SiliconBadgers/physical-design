# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Floorplan: die and core size, rows, optional pin placement and the power grid. Writes floorplan.db.
source $::env(SCRIPTS)/pnr/common.tcl
sb_init_design
set out $::env(OUT_DIR)

# core from the target utilization and aspect ratio (height / width); the die adds CORE_MARGIN on each side
set m $::env(CORE_MARGIN)
create_floorplan -site $::env(SITE) -core_margins_by die \
    -core_density_size [list $::env(ASPECT_RATIO) [expr {$::env(CORE_UTILIZATION) / 100.0}] $m $m $m $m]

# your pin placement (edit_pin commands); pins left unplaced go next to their logic in place
if {[env_or IO_CONSTRAINTS ""] ne ""} { source $::env(IO_CONSTRAINTS) }

source $::env(SCRIPTS)/pnr/power.tcl   ;# ring, straps and rails

# checks: floorplan, and the power grid reaching every row
sb_try check_floorplan -out_file $out/floorplan_check.rpt
sb_try check_connectivity -type special -nets [list $::env(PWR_NET) $::env(GND_NET)] -out_file $out/floorplan_pg.rpt

sb_report floorplan floorplan ""
sb_save floorplan
sb_done floorplan
exit
