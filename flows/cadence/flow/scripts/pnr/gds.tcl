# File:        gds.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Writes final.gds from finish.db with the standard-cell layouts merged in (GDS units 1 nm, like the cell GDS).
source $::env(SCRIPTS)/pnr/common.tcl
sb_open finish

sb_try set_db write_stream_virtual_connection false   ;# no "VDD:" labels on virtually connected pins
write_stream $::env(OUT_DIR)/final.gds -map_file $::env(STREAM_MAP) -merge $::env(CELL_GDS) \
    -uniquify_cell_names -mode ALL -units 1000

sb_done gds
exit
