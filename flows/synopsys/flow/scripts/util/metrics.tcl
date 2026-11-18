# File:        metrics.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Procs shared by the Design Compiler, PrimeTime and IC Compiler II scripts: environment defaults, report sections, slack summaries and the metrics JSON writer. A value that cannot be read is written as null.

# value of an environment variable, or a default when it is unset or empty
proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

# summary line; make prints every line that starts with SB:
proc sb_note {text} { puts "SB: $text" }

# result of a script, or "" when it fails
proc sb_try {script} {
    if {[catch {uplevel 1 $script} value]} { return "" }
    return $value
}

# run a report into a file; a failing report is a warning, not a stop
proc sb_report {file script} {
    if {[catch {uplevel 1 [list redirect $file $script]} msg]} {
        puts "Warning: report $file failed: $msg"
    }
}

# append a titled section to a report file; a failing report is a warning, not a stop
proc sb_section {file title script} {
    set fh [open $file a]
    puts $fh "\n[string repeat = 78]\n$title\n[string repeat = 78]"
    close $fh
    if {[catch {uplevel 1 [list redirect -append $file $script]} msg]} {
        puts "Warning: report \"$title\" failed: $msg"
    }
}

# worst slack (ns) of the max (setup) or min (hold) paths; "" when nothing is timed
proc sb_worst_slack {type} {
    set ws ""
    foreach_in_collection path [get_timing_paths -delay_type $type -max_paths 1] {
        set s [get_attribute $path slack]
        if {[string is double -strict $s] && ($ws eq "" || $s < $ws)} { set ws $s }
    }
    return $ws
}

# violating endpoints and their total negative slack (ns): {count tns}
proc sb_failing {type} {
    set paths [get_timing_paths -delay_type $type -max_paths 100000 -slack_lesser_than 0]
    set tns 0.0
    foreach_in_collection path $paths { set tns [expr {$tns + [get_attribute $path slack]}] }
    return [list [sizeof_collection $paths] $tns]
}

# a JSON number, or null (empty, infinite or not a number)
proc sb_json_value {v} {
    if {[regexp {^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$} $v]} { return $v }
    if {[string is double -strict $v] && ![catch {expr {double($v)}} d] && abs($d) < 1e300} {
        return $d
    }
    return null
}

# write a {key value ...} list as one JSON object
proc sb_json {file pairs} {
    set lines {}
    foreach {key value} $pairs { lappend lines "  \"$key\": [sb_json_value $value]" }
    set fh [open $file w]
    puts $fh "\{\n[join $lines ",\n"]\n\}"
    close $fh
}
