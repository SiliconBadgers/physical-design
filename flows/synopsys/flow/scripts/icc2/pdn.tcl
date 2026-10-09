# File:        pdn.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid (IC Compiler II): met1 rails along the rows, met4 and met5 straps, via stacks where they cross. Copy it and run with PDN_TCL=<your copy> to change the grid.

# Sizes in um (same grid as the open sky130hd platform)
set rail_width 0.48    ;# met1 rail, as wide as the cells' power pins
set m4_width   1.60    ;# met4 strap width
set m4_pitch   27.14   ;# met4: distance from one VDD strap to the next
set m4_offset  13.57   ;# met4: distance of the first strap from the core edge
set m5_width   1.60
set m5_pitch   27.20
set m5_offset  13.60

# Rails: met1 along every row, on top of the cells' VPWR and VGND pins
create_pg_std_cell_conn_pattern P_rail -layers {met1} -rail_width $rail_width
set_pg_strategy S_rail -core -pattern {{name: P_rail} {nets: {VDD VSS}}}

# Straps: VDD and VSS take turns (interleaving). met5 only when the design may use it.
set straps [subst {{{vertical_layer: met4} {width: $m4_width} {spacing: interleaving} {pitch: $m4_pitch} {offset: $m4_offset}}}]
if {$::env(MAX_ROUTING_LAYER) eq "met5"} {
    lappend straps [subst {{horizontal_layer: met5} {width: $m5_width} {spacing: interleaving} {pitch: $m5_pitch} {offset: $m5_offset}}]
}
create_pg_mesh_pattern P_mesh -layers $straps -via_rule {{intersection: adjacent} {via_master: default}}
# Straps run to the block edge and become the block's VDD and VSS pins there
set_pg_strategy S_mesh -core -pattern {{name: P_mesh} {nets: {VDD VSS}}} \
    -extension {{stop: design_boundary_and_generate_pin}}
set strategies {S_rail S_mesh}

# Macros: connect each macro's VDD and VSS pins to the straps above it
set macros [get_cells -quiet -hierarchical -filter "is_hard_macro==true"]
if {[sizeof_collection $macros]} {
    create_pg_macro_conn_pattern P_macro -pin_conn_type scattered_pin -layer {met5 met4}
    set_pg_strategy S_macro -macros $macros -pattern {{name: P_macro} {nets: {VDD VSS}}}
    lappend strategies S_macro
}

# Build all of it in one go; vias are added where shapes of the same net cross
compile_pg -strategies $strategies
