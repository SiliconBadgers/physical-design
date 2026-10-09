# File:        sta.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Tempus timing of a netlist at the setup and hold corners: pre-layout (make sta), or with the Quantus SPEF and propagated clocks (make finish).
#              Writes <STA_NAME>.rpt and the timing metrics into <STA_STAGE>.json.
source $::env(SCRIPTS)/util/sb_util.tcl

set stage $::env(STA_STAGE)            ;# sta or finish: metrics key prefix and JSON file
set name  [env_or STA_NAME $stage]     ;# report name
set out   $::env(OUT_DIR)
set rpt   $out/$name.rpt
set spef  [env_or SPEF_PREFIX ""]      ;# <prefix>_<corner>.spef (sign-off only)
set_multi_cpu_usage -local_cpu [env_or NCPU 4]

# --- 1. views, netlist, extracted wires ---
read_mmmc $::env(SCRIPTS)/mmmc.tcl
read_netlist $::env(NETLIST) -top $::env(TOP)
init_design
if {$spef ne ""} {
    foreach c {ss tt ff} { read_spef -rc_corner rc_$c ${spef}_$c.spef }
}
set_db timing_analysis_type ocv     ;# early/late analysis on every path
set_db timing_analysis_cppr both    ;# remove common clock path pessimism

# --- 2. reports: constraint problems, worst setup and hold paths, design-rule violators ---
sb_try check_timing -verbose > $rpt
report_timing -late  -max_paths 10 -path_type full_clock >> $rpt
report_timing -early -max_paths 10 -path_type full_clock >> $rpt
sb_try report_constraint -all_violators >> $rpt
sb_try report_analysis_summary >> $rpt

# --- 3. metrics ---
lassign [sb_slack -late]  setup_ws setup_tns
lassign [sb_slack -early] hold_ws hold_tns
set pairs [list \
    ${stage}__timing__setup__ws  $setup_ws \
    ${stage}__timing__setup__tns $setup_tns \
    ${stage}__timing__hold__ws   $hold_ws \
    ${stage}__timing__hold__tns  $hold_tns]
if {$spef ne ""} {
    lassign [sb_skew] skew_setup skew_hold
    lappend pairs ${stage}__clock__skew__setup $skew_setup ${stage}__clock__skew__hold $skew_hold
}
sb_write_json $out/$stage.json $pairs
puts "SB: $name setup_ws=$setup_ws setup_tns=$setup_tns hold_ws=$hold_ws hold_tns=$hold_tns -> $rpt"

sb_done $name
exit
