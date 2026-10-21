# File:        floorplan.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
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
        set box [list [expr {$bx1 - $h}] [expr {$by1 - $h}] [expr {$bx2 + $h}] [expr {$by2 + $h}]]
        if {[llength [info commands cut_rows]]} { sb_try cut_rows -area $box } else { sb_try split_row -area $box }   ;# split_row in 21.x
    }
}

# is (x, y) within 1 um of the edge of one of the boxes {x1 y1 x2 y2}?
proc sb_on_edge {x y boxes} {
    foreach b $boxes {
        lassign $b x1 y1 x2 y2
        set near   [expr {$x >= $x1 - 1 && $x <= $x2 + 1 && $y >= $y1 - 1 && $y <= $y2 + 1}]
        set inside [expr {$x > $x1 + 1 && $x < $x2 - 1 && $y > $y1 + 1 && $y < $y2 - 1}]
        if {$near && !$inside} { return 1 }
    }
    return 0
}

# floorplan_pg.rpt in one line: dangling wire ends (IMPVFC-94) where rails and straps stop at a macro halo (expected: the halo
# cuts them), at the core edge (expected only in a block without a core ring), elsewhere; and every other problem, such as opens
proc sb_pg_summary {rpt} {
    if {![file exists $rpt]} { puts "SB-WARNING: no $rpt"; return }
    set h $::env(MACRO_HALO)
    set halos {}
    foreach inst [sb_macro_insts] {
        lassign [join [get_db $inst .bbox]] x1 y1 x2 y2
        lappend halos [list [expr {$x1 - $h}] [expr {$y1 - $h}] [expr {$x2 + $h}] [expr {$y2 + $h}]]
    }
    set core [list [join [get_db designs .core_bbox]]]
    set n [dict create macro 0 core 0 elsewhere 0 other 0]
    set fh [open $rpt]
    foreach line [split [read $fh] \n] {
        if {[regexp {dangling Wire at \(([-0-9.]+), ([-0-9.]+)\)} $line -> x y]} {
            dict incr n [expr {[sb_on_edge $x $y $halos] ? "macro" : ([sb_on_edge $x $y $core] ? "core" : "elsewhere")}]
        } elseif {[regexp {^\s*(\d+) Problem\(s\) \(([^)]+)\)} $line -> count id] && $id ne "IMPVFC-94"} {
            dict incr n other $count
        }
    }
    close $fh
    puts "SB: floorplan_pg.rpt: dangling ends [dict get $n macro] at macro halos, [dict get $n core] at the core edge,\
        [dict get $n elsewhere] elsewhere; [dict get $n other] other problems"
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
sb_pg_summary $out/floorplan_pg.rpt

sb_report floorplan floorplan ""
sb_save floorplan
sb_done floorplan
exit
