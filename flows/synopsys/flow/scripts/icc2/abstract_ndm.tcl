# File:        abstract_ndm.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: IC Compiler II Library Manager: reference library of the design for use as a macro, from abstract/<top>.lef and the timing models of every corner. Writes abstract/<top>.ndm.

source $::env(SCRIPTS)/util/metrics.tcl

set top $::env(TOP)
set dir $::env(OUT_DIR)/abstract
set dbs {}
foreach c $::env(CORNERS) { lappend dbs $dir/${top}_$c.db }

file delete -force $dir/$top.ndm
create_workspace ${top}_lib -technology $::env(TECH_FILE) -flow normal
read_lef $dir/$top.lef
read_db $dbs
check_workspace
commit_workspace -force -output $dir/$top.ndm
if {![file exists $dir/$top.ndm]} { error "commit_workspace wrote no $dir/$top.ndm" }
sb_note "macro library -> $dir/$top.ndm"
