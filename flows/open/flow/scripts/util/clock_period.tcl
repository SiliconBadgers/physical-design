#!/usr/bin/env tclsh
# File:        clock_period.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Prints the period of the first create_clock in an SDC file (ns). Usage: clock_period.tcl <file.sdc> [override-period]

if {[llength $argv] < 1 || [llength $argv] > 2} {
    puts stderr "usage: clock_period.tcl <file.sdc> \[override-period\]"
    exit 2
}
set override [lindex $argv 1]

# run the SDC in a safe interpreter where only create_clock does anything
set interp [interp create -safe]
interp eval $interp {
    set ::sb_periods {}
    # placeholders for the sb_* helpers sta.tcl provides
    set sb_driving_cell BUF; set sb_driving_pin X
    set sb_load_cell BUF;    set sb_load_pin A
    proc sb_pin_cap {args} { return 0.0 }
    set ::sb_override ""
    set ::sb_override_used 0
    # SDC period, or the CLOCK_PERIOD override
    proc sb_clock_period {default} {
        if {$::sb_override eq ""} { return $default }
        set ::sb_override_used 1
        return $::sb_override
    }
    proc create_clock {args} {
        set i [lsearch -exact $args -period]
        if {$i >= 0} { lappend ::sb_periods [lindex $args [expr {$i + 1}]] }
        return clk
    }
    # every other SDC command is a no-op
    proc unknown {args} { return "" }
}

set f [open [lindex $argv 0]]
set sdc [read $f]
close $f

interp eval $interp [list set ::sb_override $override]
if {[catch {interp eval $interp $sdc} err]} {
    puts stderr "clock_period.tcl: error while reading [lindex $argv 0]: $err"
    exit 1
}
set periods [interp eval $interp {set ::sb_periods}]
if {[llength $periods] == 0} {
    puts stderr "clock_period.tcl: no 'create_clock -period' found in [lindex $argv 0]"
    exit 1
}
if {$override ne "" && ![interp eval $interp {set ::sb_override_used}]} {
    puts stderr "clock_period.tcl: CLOCK_PERIOD=$override given, but [lindex $argv 0] never calls"
    puts stderr "  sb_clock_period, so the override would be ignored. Write the period as"
    puts stderr "  `set clk_period \[sb_clock_period <ns>\]` (see docs/writing_sdc.md)."
    exit 1
}
# the first clock is the core clock
puts [lindex $periods 0]
