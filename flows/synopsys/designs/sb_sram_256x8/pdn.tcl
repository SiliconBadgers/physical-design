# File:        pdn.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid of the sb_sram_256x8 block (IC Compiler II): met1 rails and met4 straps, no met5. The met4 straps become the block's VDD and VSS pins, so the tile connects to them from met5.

# Rails: met1 along every row, on top of the cells' VPWR and VGND pins
create_pg_std_cell_conn_pattern P_rail -layers {met1} -rail_width 0.48
set_pg_strategy S_rail -core -pattern {{name: P_rail} {nets: {VDD VSS}}}

# Straps: VDD and VSS take turns, inside the core (CORE_MARGIN from the block edge)
create_pg_mesh_pattern P_m4 -layers {{{vertical_layer: met4} {width: 1.60} {spacing: interleaving} {pitch: 27.14} {offset: 13.57}}}
set_pg_strategy S_m4 -core -pattern {{name: P_m4} {nets: {VDD VSS}}}

# Build both; vias are added where shapes of the same net cross
compile_pg -strategies {S_rail S_m4}

# The met4 straps become terminals of the VDD and VSS ports: the block's power pins
foreach net {VDD VSS} {
    set straps [get_shapes -quiet -of_objects [get_nets $net] -filter "layer_name==met4"]
    if {![sizeof_collection $straps]} { error "no met4 straps on $net" }
    # -of_objects copies the net's shapes as terminals of its port (-object with -port refuses a shape that
    # belongs to a net: NDMUI-132)
    create_terminal -of_objects $straps
    if {![sizeof_collection [get_terminals -quiet -of_objects [get_ports $net]]]} { error "no terminals on port $net" }
}
