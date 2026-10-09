# File:        synth.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Genus synthesis: RTL to a netlist of sky130_scl_9T cells timed at the setup corner, with tie cells and reports. Inputs are environment variables from synth.env, written by make.
source $::env(SCRIPTS)/util/sb_util.tcl

set top    $::env(TOP)
set out    $::env(OUT_DIR)
set effort [env_or SYNTH_EFFORT medium]
set_multi_cpu_usage -local_cpu [env_or NCPU 4]

# --- 1. settings ---
sb_try set_db hdl_error_on_blackbox true         ;# a missing module is an error, not an empty box
sb_try set_db hdl_track_filename_row_col true    ;# messages give file and line
set_db syn_generic_effort $effort
set_db syn_map_effort $effort
set_db syn_opt_effort $effort

# --- 2. libraries (every corner) and SDC through MMMC, cell abstracts from the LEF ---
read_mmmc $::env(SCRIPTS)/mmmc.tcl
read_physical -lef [concat $::env(TECH_LEF) $::env(CELL_LEF)]

# --- 3. read and elaborate the RTL ---
if {[env_or RTL_INCDIRS ""] ne ""} { set_db init_hdl_search_path $::env(RTL_INCDIRS) }
set defines {}
foreach d [env_or RTL_DEFINES ""] { lappend defines -define $d }
read_hdl -language sv {*}$defines $::env(RTL_FILES)
elaborate $top
init_design -top $top

# cells synthesis must not use
foreach pattern [env_or DONT_USE ""] {
    set cells [get_db base_cells $pattern]
    if {[llength $cells]} { sb_try set_db $cells .dont_use true }
}

# --- 4. generic gates, then library cells, then optimization ---
syn_generic
syn_map
syn_opt

# --- 5. tie cells: every constant input gets its own TIEHI or TIELO ---
# the tie cell of the setup corner's library set, or its plain name
proc sb_tie_cell {name} {
    set lib_set libs_[lindex [env_or SETUP_CORNERS ss] 0]
    if {![catch {get_db base_cell:$name .lib_cells -if ".library.library_set.name == $lib_set"} cells]
        && [llength $cells]} {
        return [lindex $cells 0]
    }
    return $name
}
sb_try set_db use_tiehilo_for_const duplicate
sb_try add_tieoffs -high [sb_tie_cell $::env(TIEHI_CELL)] -low [sb_tie_cell $::env(TIELO_CELL)] -max_fanout 1 -verbose

# --- 6. checks and reports ---
check_design -all            > $out/synth_check_design.rpt
check_timing_intent -verbose > $out/synth_check_timing.rpt
report_timing -max_paths 10  > $out/synth_timing.rpt
report_area                  > $out/synth_area.rpt
report_gates                 > $out/synth_gates.rpt
report_qor                   > $out/synth_qor.rpt
sb_try report_power          > $out/synth_power.rpt

# --- 7. netlist, and the constraints as Genus applied them ---
write_hdl > $out/netlist.v
sb_try write_sdc -view view_[lindex [env_or SETUP_CORNERS ss] 0] > $out/netlist.sdc

sb_done synth
exit
