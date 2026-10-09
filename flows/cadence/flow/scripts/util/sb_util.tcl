# File:        sb_util.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Helpers shared by the Genus, Innovus, Tempus and Voltus scripts: settings from the environment, soft-fail commands, slack and skew numbers, and the metrics JSON.

# value of an environment variable, or a default when it is unset or empty
proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

# run a non-essential command; on error print SB-WARNING and go on
proc sb_try {args} {
    if {[catch {uplevel 1 $args} msg]} {
        puts "SB-WARNING: [string range $args 0 100] failed: $msg"
    }
}

# result of a script, or null if it fails or returns nothing
proc sb_value {script} {
    if {[catch {uplevel 1 $script} value] || $value eq ""} { return null }
    return $value
}

# last line of every script; make checks for it in the log
proc sb_done {name} {
    puts "SB: $name done"
}

# a property of a timing path or pin: get_property, else get_db
proc sb_prop {obj name} {
    if {![catch {get_property $obj $name} value]} { return $value }
    return [get_db $obj .$name]
}

# worst slack and total negative slack over all endpoints; check is -late (setup) or -early (hold)
proc sb_slack {check} {
    set ws [sb_value {
        set s ""
        foreach_in_collection p [report_timing $check -max_paths 1 -collection] { set s [sb_prop $p slack] }
        set s
    }]
    set tns [sb_value {
        set t 0.0
        foreach_in_collection p [report_timing $check -max_paths 100000 -nworst 1 -max_slack 0 -collection] {
            set s [sb_prop $p slack]
            if {[string is double -strict $s]} { set t [expr {$t + $s}] }
        }
        set t
    }]
    return [list $ws $tns]
}

# clock skew {setup hold}: spread of the late and of the early clock arrival over all register clock pins
proc sb_skew {} {
    set skew {}
    foreach kind {max min} {
        set lo ""
        set hi ""
        catch {
            foreach_in_collection pin [all_registers -clock_pins] {
                set a [sb_prop $pin arrival_${kind}_rise]
                if {[string is double -strict $a]} {
                    if {$lo eq "" || $a < $lo} { set lo $a }
                    if {$hi eq "" || $a > $hi} { set hi $a }
                }
            }
        }
        lappend skew [expr {$lo eq "" ? "null" : $hi - $lo}]
    }
    return $skew
}

# one value as JSON: integer, number, null (also for INF and NaN) or string
proc sb_json_value {v} {
    if {$v eq "" || $v eq "null"} { return null }
    if {[string is integer -strict $v]} { return $v }
    if {[string is double -strict $v]} {
        if {[string match -nocase *inf* $v] || [string match -nocase *nan* $v]} { return null }
        return [format %.10g $v]   ;# drops float noise such as 0.08000000000000002
    }
    return "\"[string map {\\ \\\\ \" \\\"} $v]\""
}

# key/value pairs of a flat JSON object written by sb_write_json (empty if the file does not exist)
proc sb_read_json {file} {
    set d [dict create]
    if {![file exists $file]} { return $d }
    set fh [open $file]
    set text [read $fh]
    close $fh
    foreach {- key value} [regexp -all -inline {"([^"]+)"\s*:\s*("[^"]*"|[^,\s\}]+)} $text] {
        dict set d $key [string trim $value {"}]
    }
    return $d
}

# metrics file: a flat JSON object; the pairs are added to the file if it exists (finish: Innovus, then Tempus)
proc sb_write_json {file pairs} {
    set d [sb_read_json $file]
    foreach {key value} $pairs { dict set d $key $value }
    set lines {}
    dict for {key value} $d { lappend lines "  \"$key\": [sb_json_value $value]" }
    set fh [open $file w]
    puts $fh "\{\n[join $lines ",\n"]\n\}"
    close $fh
}
