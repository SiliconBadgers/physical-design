# File:        place.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Placement: global placement, pin placement, electrical repair and legalization. Writes place.odb.
source $::env(SCRIPTS)/pnr/common.tcl
sb_load floorplan.odb

set density $::env(PLACE_DENSITY)

# rough placement without pins, then pins next to their logic
global_placement -skip_io -density $density
if {[env_or IO_CONSTRAINTS ""] ne ""} { source $::env(IO_CONSTRAINTS) }
place_pins -hor_layers $::env(IO_H_LAYER) -ver_layers $::env(IO_V_LAYER)

# synthesis buffers out (repair_design re-buffers from real distances); optionally a buffer on every port
remove_buffers
if {[env_or BUFFER_PORTS 0]} { buffer_ports }

# full placement, timing and routability driven unless switched off
set gpl_args {}
if {[env_or GPL_TIMING_DRIVEN 1]} { lappend gpl_args -timing_driven }
if {[env_or GPL_ROUTABILITY_DRIVEN 1]} { lappend gpl_args -routability_driven }
global_placement -density $density {*}$gpl_args

# fix slew, capacitance and fanout, then put every cell on a legal site
estimate_parasitics -placement
repair_design
detailed_placement
check_placement -verbose

sb_report detailedplace
write_db $::env(OUT_DIR)/place.odb
