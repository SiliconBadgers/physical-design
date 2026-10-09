# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Floorplan: die and core size, rows, hard macro placement with halos, optional pin placement and the power grid. Writes floorplan.db.
source $::env(SCRIPTS)/pnr/common.tcl
sb_init_design
set out $::env(OUT_DIR)

# macro cell -> {width height} from the macro LEFs
proc sb_macro_sizes {} {
    set sizes [dict create]
    foreach lef [env_or MACRO_LEFS ""] {
        set fh [open $lef]
        set cell ""
        foreach line [split [read $fh] \n] {
            if {[regexp {^\s*MACRO\s+(\S+)} $line -> name]} { set cell $name }
            if {$cell ne "" && [regexp {^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)} $line -> w h]} {
                dict set sizes $cell [list $w $h]
                set cell ""
            }
        }
        close $fh
    }
    return $sizes
}

# hard macros as {instance width height}, sorted by instance name
proc sb_macro_list {} {
    set sizes [sb_macro_sizes]
    set out {}
    foreach inst [sb_macro_insts] {
        set cell [get_db $inst .base_cell.name]
        if {![dict exists $sizes $cell]} { error "no SIZE for macro $cell in MACRO_LEFS" }
        lappend out [concat [list [get_db $inst .name]] [dict get $sizes $cell]]
    }
    return [lsort -dictionary -index 0 $out]
}

# macro corners {instance x y}: centred rows from the top of the core, MACRO_CHANNEL apart and from the edge; empty if they do not fit
proc sb_pack_macros {box macros} {
    lassign $box x1 y1 x2 y2
    set ch $::env(MACRO_CHANNEL)
    set g  $::env(MACRO_GRID)
    # rows {macros width}; a macro needs its width, a channel and one grid step (snapping)
    set rows {}
    set row {}
    set used $ch
    foreach m $macros {
        set need [expr {[lindex $m 1] + $ch + $g}]
        if {[llength $row] && $used + $need > $x2 - $x1} {
            lappend rows [list $row $used]
            set row {}
            set used $ch
        }
        lappend row $m
        set used [expr {$used + $need}]
    }
    if {[llength $row]} { lappend rows [list $row $used] }

    set placed {}
    set top [expr {$y2 - $ch}]
    foreach r $rows {
        lassign $r row used
        set h 0.0
        foreach m $row { set h [expr {max($h, [lindex $m 2])}] }
        set y [expr {floor(($top - $h) / $g) * $g}]
        if {$y < $y1 + $ch} { return {} }
        set x [expr {$x1 + ($x2 - $x1 - $used) / 2.0 + $ch}]
        foreach m $row {
            lassign $m inst w
            set x [expr {ceil($x / $g) * $g}]
            if {$x < $x1 + $ch || $x + $w > $x2 - $ch} { return {} }
            lappend placed [list $inst [format %.3f $x] [format %.3f $y]]
            set x [expr {$x + $w + $ch}]
        }
        set top [expr {$y - $ch}]
    }
    return $placed
}

# core {width height}: area of every instance / CORE_UTILIZATION at ASPECT_RATIO, grown until the macros fit
proc sb_macro_core {macros} {
    set fixed [dict create]
    foreach m $macros { dict set fixed [lindex $m 0] [expr {[lindex $m 1] * [lindex $m 2]}] }
    set area 0.0
    foreach name [get_db insts .name] a [get_db insts .area] {
        set area [expr {$area + ([dict exists $fixed $name] ? [dict get $fixed $name] : $a)}]
    }
    set ar $::env(ASPECT_RATIO)
    set g  $::env(MACRO_GRID)
    set w  [expr {sqrt($area / ($::env(CORE_UTILIZATION) / 100.0) / $ar)}]
    for {set i 0} {$i < 100} {incr i} {
        set h [expr {$w * $ar}]
        if {[llength [sb_pack_macros [list $g $g [expr {$w - $g}] [expr {$h - $g}]] $macros]]} { return [list $w $h] }
        set w [expr {$w * 1.05}]
    }
    error "the macros do not fit in any core up to [format %.0f $w] um wide"
}

# place the macros (fixed), then the halos: no standard cells, rows or unrelated wires near them
proc sb_place_macros {macros} {
    set placed [sb_pack_macros [join [get_db designs .core_bbox]] $macros]
    if {![llength $placed]} { error "the macros do not fit in the core" }
    foreach p $placed {
        lassign $p name x y
        if {[catch {place_inst $name $x $y r0 -fixed}] && [catch {place_inst $name [list $x $y] r0 -fixed} msg]} {
            error "place_inst $name: $msg"
        }
        puts "SB: macro $name at ($x, $y)"
    }
    set h $::env(MACRO_HALO)
    if {[catch {create_place_halo -all_blocks -halo_deltas [list $h $h $h $h]}]} {
        foreach p $placed { create_place_halo -insts [lindex $p 0] -halo_deltas [list $h $h $h $h] }
    }
    sb_try create_route_halo -all_blocks -bottom_layer $::env(MIN_ROUTING_LAYER) -top_layer $::env(MACRO_TOP_LAYER) -space $h
    foreach inst [sb_macro_insts] {
        lassign [join [get_db $inst .bbox]] bx1 by1 bx2 by2
        sb_try cut_rows -area [list [expr {$bx1 - $h}] [expr {$by1 - $h}] [expr {$bx2 + $h}] [expr {$by2 + $h}]]
    }
}

# core from the target utilization and aspect ratio (height / width); the die adds CORE_MARGIN on each side
set m $::env(CORE_MARGIN)
set macros [sb_macro_list]
if {[llength $macros]} {
    lassign [sb_macro_core $macros] w h
    create_floorplan -site $::env(SITE) -core_margins_by die -core_size [list $w $h $m $m $m $m]
    sb_place_macros $macros
} else {
    create_floorplan -site $::env(SITE) -core_margins_by die \
        -core_density_size [list $::env(ASPECT_RATIO) [expr {$::env(CORE_UTILIZATION) / 100.0}] $m $m $m $m]
}

# your pin placement (edit_pin commands); pins left unplaced go next to their logic in place
if {[env_or IO_CONSTRAINTS ""] ne ""} { source $::env(IO_CONSTRAINTS) }

source [env_or PDN_TCL $::env(SCRIPTS)/pnr/power.tcl]   ;# power grid

# checks: floorplan, and the power grid reaching every row
sb_try check_floorplan -out_file $out/floorplan_check.rpt
sb_try check_connectivity -type special -nets [list $::env(PWR_NET) $::env(GND_NET)] -out_file $out/floorplan_pg.rpt

sb_report floorplan floorplan ""
sb_save floorplan
sb_done floorplan
exit
