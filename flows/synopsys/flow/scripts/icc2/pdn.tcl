# File:        pdn.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Power grid (IC Compiler II): met1 rails along the rows, met4 and met5 straps, via stacks where they cross; with hard macros, met5 runs over them and connects to their met4 power pins. Copy it and run with PDN_TCL=<your copy> to change the grid.

# Sizes in um (same grid as the open sky130hd platform)
set rail_width 0.48    ;# met1 rail, as wide as the cells' power pins
set m4_width   1.60    ;# met4 strap width
set m4_pitch   27.14   ;# met4: distance from one VDD strap to the next
set m4_offset  13.57   ;# met4: distance of the first strap from the core edge
set m5_width   1.60
set m5_pitch   27.20
set m5_offset  13.60

# Hard macros: rails and met4 straps stop at them (the macros use met1 to met4)
set macros [get_cells -quiet -hierarchical -filter "is_hard_macro==true"]
set avoid_macros {}
if {[sizeof_collection $macros]} {
    if {$::env(MAX_ROUTING_LAYER) ne "met5"} { error "hard macros need met5 straps over them: MAX_ROUTING_LAYER must be met5" }
    set avoid_macros [list -blockage [list macros: [get_object_name $macros]]]
}

# Rails: met1 along every row, on top of the cells' VPWR and VGND pins
create_pg_std_cell_conn_pattern P_rail -layers {met1} -rail_width $rail_width
set_pg_strategy S_rail -core -pattern {{name: P_rail} {nets: {VDD VSS}}} {*}$avoid_macros

# Straps: VDD and VSS take turns (interleaving). met5 only when the design may use it.
# They run to the block edge and become the block's VDD and VSS pins there.
set m4 [subst {{vertical_layer: met4} {width: $m4_width} {spacing: interleaving} {pitch: $m4_pitch} {offset: $m4_offset}}]
set m5 [subst {{horizontal_layer: met5} {width: $m5_width} {spacing: interleaving} {pitch: $m5_pitch} {offset: $m5_offset}}]
set extension {{stop: design_boundary_and_generate_pin}}
if {![sizeof_collection $macros]} {
    set straps [list $m4]
    if {$::env(MAX_ROUTING_LAYER) eq "met5"} { lappend straps $m5 }
    create_pg_mesh_pattern P_mesh -layers $straps -via_rule {{intersection: adjacent} {via_master: default}}
    set_pg_strategy S_mesh -core -pattern {{name: P_mesh} {nets: {VDD VSS}}} -extension $extension
    set strategies {S_rail S_mesh}
} else {
    # met4 stops at the macros; met5 crosses them, with vias down to the macros' met4 VDD and VSS pins where they cross
    create_pg_mesh_pattern P_m4 -layers [list $m4]
    set_pg_strategy S_m4 -core -pattern {{name: P_m4} {nets: {VDD VSS}}} -extension $extension {*}$avoid_macros
    create_pg_mesh_pattern P_m5 -layers [list $m5]
    set_pg_strategy S_m5 -core -pattern {{name: P_m5} {nets: {VDD VSS}}} -extension $extension
    set strategies {S_rail S_m4 S_m5}
}

# Build all of it in one go; vias are added where shapes of the same net cross
compile_pg -strategies $strategies
