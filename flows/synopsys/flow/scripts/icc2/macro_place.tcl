# File:        macro_place.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Places the hard macros in rows from the top-left corner of the core, MACRO_CHANNEL apart and from the core edge, fixes them and keeps standard cells MACRO_HALO away. Sourced by floorplan.tcl.

set halo    $::env(MACRO_HALO)      ;# standard-cell keep-out around each macro (um)
set channel $::env(MACRO_CHANNEL)   ;# space between macros, and between a macro and the core edge (um)
set grid_x  0.92                    ;# met2 and met4 pitch: the macro pins stay on the routing tracks
set grid_y  3.40                    ;# met1, met3 and met5 pitch

# value rounded up or down to a multiple of grid
proc snap {value grid dir} {
    set n [expr {$value / $grid}]
    set n [expr {$dir eq "up" ? ceil($n - 1e-9) : floor($n + 1e-9)}]
    return [format %.3f [expr {$n * $grid}]]
}

lassign [get_attribute [get_core_area] bbox] core_ll core_ur
lassign $core_ll cx0 cy0
lassign $core_ur cx1 cy1
set left   [snap [expr {$cx0 + $channel}] $grid_x up]
set x      $left
set top    [expr {$cy1 - $channel}]   ;# top edge of the current row
set bottom $top                       ;# lowest macro edge in the current row
set macros [sort_collection [get_cells -hierarchical -filter "is_hard_macro==true"] full_name]
foreach_in_collection m $macros {
    lassign [get_attribute $m bbox] ll ur
    set w [expr {[lindex $ur 0] - [lindex $ll 0]}]
    set h [expr {[lindex $ur 1] - [lindex $ll 1]}]
    if {$x > $left && $x + $w > $cx1 - $channel} {   ;# row full: start the next row below it
        set x $left
        set top [expr {$bottom - $channel}]
        set bottom $top
    }
    set y [snap [expr {$top - $h}] $grid_y down]
    if {$x + $w > $cx1 - $channel || $y < $cy0 + $channel} {
        error "macro [get_object_name $m] does not fit in the core with MACRO_CHANNEL=$channel um: lower CORE_UTILIZATION"
    }
    set_cell_location -coordinates [list $x $y] -orientation R0 $m
    sb_note "macro [get_object_name $m] at ($x, $y)"
    set bottom [expr {min($bottom, $y)}]
    set x [snap [expr {$x + $w + $channel}] $grid_x up]
}
set_attribute $macros physical_status fixed
create_keepout_margin -type hard -outer [list $halo $halo $halo $halo] $macros
