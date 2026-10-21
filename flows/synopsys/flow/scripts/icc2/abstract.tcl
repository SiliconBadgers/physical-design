# File:        abstract.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: LEF of the finished design for use as a macro: its frame view with pins and blockages. Writes the icc2/abstract checkpoint and abstract/<top>.lef.
source $::env(SCRIPTS)/icc2/common.tcl
open_stage finish abstract

set lef $OUT/abstract/$TOP.lef
file mkdir [file dirname $lef]
file delete -force $lef

# The parent's power grid joins this block on the met4 straps, which write_lef exports as
# the block's power and ground pins. A PDN that generates boundary pins (generate_pin)
# already leaves VDD/VSS terminals; otherwise promote the met4 straps to terminals here as
# a fallback (with -of_objects, since -port/-object is rejected for a shape already on a net).
foreach net {VDD VSS} {
    if {[sizeof_collection [get_terminals -quiet -of_objects [get_ports $net]]]} { continue }
    set straps [get_shapes -quiet -of_objects [get_nets $net] -filter "layer_name==met4"]
    if {![sizeof_collection $straps]} { error "no met4 straps on $net: the design's pdn.tcl must route met4 power straps" }
    create_terminal -of_objects $straps
}

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
