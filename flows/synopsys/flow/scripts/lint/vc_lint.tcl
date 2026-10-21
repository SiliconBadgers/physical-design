# File:        vc_lint.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: VC SpyGlass RTL lint (vc_static_shell, goal lint_rtl). Inputs are environment variables set by run_lint.sh.

# value of an environment variable, or a default when it is unset or empty
proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set top       $::env(TOP)              ;# top module
set rtl_files $::env(RTL_FILES)        ;# RTL and macro simulation models
set incdirs   [env_or RTL_INCDIRS ""]
set defines   [env_or RTL_DEFINES ""]

set_app_var enable_lint true
configure_lint_setup -goal lint_rtl    ;# the standard RTL rule set

set vcs_opts {}
foreach d $incdirs { lappend vcs_opts +incdir+$d }
foreach d $defines { lappend vcs_opts +define+$d }
set analyze_args [list -format sverilog]
if {[llength $vcs_opts]} { lappend analyze_args -vcs [join $vcs_opts " "] }
analyze {*}$analyze_args $rtl_files
elaborate $top

check_lint
report_lint -verbose -file lint_vc.rpt
quit
