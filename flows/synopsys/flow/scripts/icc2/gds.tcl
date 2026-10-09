# File:        gds.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Writes final.gds from the finish checkpoint, with the cell and macro layouts merged in. The layer map comes from the PDK repo (GDS_MAP).
source $::env(SCRIPTS)/icc2/common.tcl
open_lib [stage_lib finish]
open_block $TOP

file delete -force $OUT/final.gds
write_gds -layer_map $::env(GDS_MAP) -merge_files [concat $::env(CELL_GDS) [env_or MACRO_GDS ""]] -long_names $OUT/final.gds
if {![file exists $OUT/final.gds]} { error "write_gds wrote no $OUT/final.gds" }
sb_note "wrote $OUT/final.gds"
