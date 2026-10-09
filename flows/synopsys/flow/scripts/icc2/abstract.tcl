# File:        abstract.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: LEF of the finished design for use as a macro: its frame view with pins and blockages. Writes the icc2/abstract checkpoint and abstract/<top>.lef.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage finish abstract

set lef $OUT/abstract/$TOP.lef
file mkdir [file dirname $lef]
file delete -force $lef

# every layer the design uses is fully blocked; layers above it stay free for the parent's routing
create_frame -block_all used_layers
write_lef -include cell -design $TOP.frame $lef
if {![file exists $lef]} { error "write_lef wrote no $lef" }

# the parent connects its power grid to these pins
set fh [open $lef]
set text [read $fh]
close $fh
foreach net {VDD VSS} {
    if {![regexp "PIN $net\\s(.*?)\\sEND $net" $text -> body] || ![string match "*LAYER met4*" $body]} {
        error "$lef has no met4 pin $net (the design's pdn.tcl must make its met4 straps terminals)"
    }
}
sb_note "abstract LEF -> $lef"
save_stage
