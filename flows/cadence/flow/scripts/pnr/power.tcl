# File:        power.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid: ring around the core (met4/met5), met4 and met5 straps, met1 rails along the rows; the met5 straps connect to the met4 power pins of hard macros. Sourced by floorplan.tcl.
set nets    [list $::env(PWR_NET) $::env(GND_NET)]
set pitch   $::env(PDN_STRAP_PITCH)   ;# um from one VDD/VSS strap pair to the next
set width   1.6                       ;# strap width (um)
set spacing 1.7                       ;# um between the VDD and the VSS strap of a pair

lassign [join [get_db designs .core_bbox]] cx1 cy1 cx2 cy2
lassign [join [get_db designs .bbox]] dx1 dy1 dx2 dy2

# hard macros and their halo: no met4 straps over them (met4 is the macros' top layer)
set keepout {}
foreach inst [sb_macro_insts] {
    lassign [join [get_db $inst .bbox]] x1 y1 x2 y2
    set h $::env(MACRO_HALO)
    lappend keepout [list [expr {$x1 - $h}] [expr {$y1 - $h}] [expr {$x2 + $h}] [expr {$y2 + $h}]]
}
set met4_keepout [expr {[llength $keepout] ? [list -area_blockage $keepout] : {}}]

# ring around the core: horizontal sides on met5, vertical sides on met4
add_rings -nets $nets -type core_rings -follow core \
    -layer {top met5 bottom met5 left met4 right met4} \
    -width 2.0 -spacing $spacing -offset 1.0

# vertical met4 straps across the core, with via stacks down to met1
set_db add_stripes_stacked_via_bottom_layer met1
set_db add_stripes_stacked_via_top_layer    met4
add_stripes -nets $nets -layer met4 -direction vertical \
    -width $width -spacing $spacing -set_to_set_distance $pitch \
    -area [list $cx1 $cy1 $cx2 $cy2] -start [expr {$cx1 + $pitch / 2.0}] {*}$met4_keepout

# horizontal met5 straps from die edge to die edge; their ends become the block's VDD/VSS pins (Voltus feeds power in there)
# they cross the macros and drop vias onto the macros' met4 power pins (vias are skipped on standard-cell pins only)
set_db add_stripes_stacked_via_bottom_layer met4
set_db add_stripes_stacked_via_top_layer    met5
if {[llength $keepout]} { sb_try set_db add_stripes_skip_via_on_pin standardcell }
add_stripes -nets $nets -layer met5 -direction horizontal \
    -width $width -spacing $spacing -set_to_set_distance $pitch \
    -area [list $dx1 $cy1 $dx2 $cy2] -start [expr {$cy1 + $pitch / 2.0}] \
    -create_pins 1

# met1 rails along every row under the cells' VDD/VSS pins, with vias up to the straps they cross
# rows cut at a macro end there (no extension to a target across the macro)
set rail_target [expr {[llength $keepout] ? {} : {-core_pin_target {first_after_row_end}}}]
route_special -connect {core_pin} -nets $nets {*}$rail_target \
    -allow_jogging 1 -allow_layer_change 1 \
    -layer_change_range {met1 met5} \
    -crossover_via_layer_range {met1 met5} \
    -target_via_layer_range {met1 met5}
