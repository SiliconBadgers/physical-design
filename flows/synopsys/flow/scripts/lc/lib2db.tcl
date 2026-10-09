# File:        lib2db.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Library Compiler: compiles the timing model abstract/<top>_<corner>.lib into abstract/<top>_<corner>.db. Inputs are environment variables from model_<corner>.env, written by the Makefile.

source $::env(SCRIPTS)/util/metrics.tcl

set name $::env(TOP)_$::env(CORNER)   ;# library name, set by pt/model.tcl
set base $::env(OUT_DIR)/abstract/$name

file delete -force $base.db
read_lib $base.lib
write_lib $name -format db -output $base.db
if {![file exists $base.db]} { error "write_lib wrote no $base.db" }
sb_note "compiled $base.db"
