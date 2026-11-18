# File:        gds.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Writes final.gds from the finish checkpoint, with the cell and macro layouts merged in. The layer map comes from the PDK repo (GDS_MAP).
source $::env(SCRIPTS)/icc2/common.tcl
open_lib [stage_lib finish]
open_block $TOP

file delete -force $OUT/final.gds
# -merge_gds_top_cell: keep only the merged cells under $TOP; without it every unused cell of the merged GDS
# files is written as another top cell, and KLayout DRC and LVS stop ("multiple top cells")
# -merge_overwrite_conflicting_cell: a macro GDS has its own copies of the standard cells; keep one of each
# (the last file's) instead of renaming the macro's copies <cell>_R<n>, which LVS cannot match to the CDL
write_gds -layer_map $::env(GDS_MAP) -merge_files [concat $::env(CELL_GDS) [env_or MACRO_GDS ""]] \
    -merge_gds_top_cell $TOP -merge_overwrite_conflicting_cell -long_names $OUT/final.gds
if {![file exists $OUT/final.gds]} { error "write_gds wrote no $OUT/final.gds" }
sb_note "wrote $OUT/final.gds"
