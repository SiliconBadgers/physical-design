# File:        pdn.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid of the sb_sram_256x8 block: met1 rails and vertical straps on its top layer (met4), no ring and no met5. The straps are the macro's power pins.
set nets  [list $::env(PWR_NET) $::env(GND_NET)]
set pitch $::env(PDN_STRAP_PITCH)     ;# um from one VDD/VSS strap pair to the next
set layer $::env(MAX_ROUTING_LAYER)   ;# met4 (vertical)

lassign [join [get_db designs .core_bbox]] cx1 cy1 cx2 cy2
lassign [join [get_db designs .bbox]] dx1 dy1 dx2 dy2

# straps from die edge to die edge; pins at their ends give the block its VDD/VSS ports
set_db add_stripes_stacked_via_bottom_layer met1
set_db add_stripes_stacked_via_top_layer    $layer
add_stripes -nets $nets -layer $layer -direction vertical \
    -width 1.6 -spacing 1.7 -set_to_set_distance $pitch \
    -area [list $cx1 $dy1 $cx2 $dy2] -start [expr {$cx1 + $pitch / 2.0}] \
    -create_pins 1

# met1 rails along every row under the cells' VDD/VSS pins, with vias up to the straps they cross
route_special -connect {core_pin} -nets $nets \
    -allow_jogging 1 -allow_layer_change 1 \
    -layer_change_range [list met1 $layer] \
    -crossover_via_layer_range [list met1 $layer] \
    -target_via_layer_range [list met1 $layer]
