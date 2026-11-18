# File:        gds.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Writes final.gds from finish.db with the standard-cell and macro layouts merged in (GDS units 1 nm, like the cell GDS).
#              Pin shapes are also written as drawing metal, so a wire that ends at a pin of this design connects.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open finish
set out $::env(OUT_DIR)

# stream map: the PDK map, plus the pin shapes of each metal layer on its drawing (net) datatype
set fh [open $::env(STREAM_MAP)]
set lines [split [read $fh] \n]
close $fh
set net [dict create]
foreach line $lines {
    if {[regexp {^\s*(\w+)\s+net\s+(\d+)\s+(\d+)} $line -> layer gl gd]} { dict set net $layer "$gl $gd" }
}
set map [open $out/stream.map w]
puts $map [join $lines \n]
foreach line $lines {
    if {[regexp {^\s*(met\d)\s+pin\s+\d+\s+\d+} $line -> layer] && [dict exists $net $layer]} {
        puts $map "$layer pin [dict get $net $layer]"
    }
}
close $map

sb_try set_db write_stream_virtual_connection false   ;# no "VDD:" labels on virtually connected pins
# GDS units 1 nm: -unit in Innovus 21.x, -units in later releases
write_stream $out/final.gds -map_file $out/stream.map -merge [concat $::env(CELL_GDS) [env_or MACRO_GDS ""]] \
    -uniquify_cell_names -mode ALL [expr {[sb_innovus21] ? "-unit" : "-units"}] 1000

sb_done gds
exit
