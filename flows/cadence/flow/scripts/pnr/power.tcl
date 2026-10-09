# File:        power.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid: ring around the core (met4/met5), met4 and met5 straps, met1 rails along the rows. Sourced by floorplan.tcl.
set nets    [list $::env(PWR_NET) $::env(GND_NET)]
set pitch   $::env(PDN_STRAP_PITCH)   ;# um from one VDD/VSS strap pair to the next
set width   1.6                       ;# strap width (um)
set spacing 1.7                       ;# um between the VDD and the VSS strap of a pair

lassign [join [get_db designs .core_bbox]] cx1 cy1 cx2 cy2
lassign [join [get_db designs .bbox]] dx1 dy1 dx2 dy2

# ring around the core: horizontal sides on met5, vertical sides on met4
add_rings -nets $nets -type core_rings -follow core \
    -layer {top met5 bottom met5 left met4 right met4} \
    -width 2.0 -spacing $spacing -offset 1.0

# vertical met4 straps across the core, with via stacks down to met1
set_db add_stripes_stacked_via_bottom_layer met1
set_db add_stripes_stacked_via_top_layer    met4
add_stripes -nets $nets -layer met4 -direction vertical \
    -width $width -spacing $spacing -set_to_set_distance $pitch \
    -area [list $cx1 $cy1 $cx2 $cy2] -start [expr {$cx1 + $pitch / 2.0}]

# horizontal met5 straps from die edge to die edge; their ends become the block's VDD/VSS pins (Voltus feeds power in there)
set_db add_stripes_stacked_via_bottom_layer met4
set_db add_stripes_stacked_via_top_layer    met5
add_stripes -nets $nets -layer met5 -direction horizontal \
    -width $width -spacing $spacing -set_to_set_distance $pitch \
    -area [list $dx1 $cy1 $dx2 $cy2] -start [expr {$cy1 + $pitch / 2.0}] \
    -create_pins 1

# met1 rails along every row under the cells' VDD/VSS pins, with vias up to the straps they cross
route_special -connect {core_pin} -nets $nets \
    -core_pin_target {first_after_row_end} \
    -allow_jogging 1 -allow_layer_change 1 \
    -layer_change_range {met1 met5} \
    -crossover_via_layer_range {met1 met5} \
    -target_via_layer_range {met1 met5}
