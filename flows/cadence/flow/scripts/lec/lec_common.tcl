# File:        lec_common.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Shared procs for the Conformal dofiles (tclmode): log, libraries, hard macros as black boxes, and the compare with the counts make reads.
#              Inputs are environment variables from lec.env, written by make; LEC_REVISED and LEC_LOG override the revised netlist and the log (lec_mutation.py).
source $::env(SCRIPTS)/util/sb_util.tcl

# log file and threads
proc sb_lec_start {name} {
    set_log_file [env_or LEC_LOG logs/$name.log] -replace
    sb_try set_parallel_option -threads [env_or NCPU 4]
}

# cell and tie-cell libraries at tt (the logic is the same at every corner); a macro's timing model has no logic, so it reads as a black box
proc sb_lec_libraries {} {
    read_library -liberty -both {*}[concat $::env(LIB_tt) $::env(LIB_EXTRA) [env_or MACRO_LIB_tt ""]]
}

# hard macros as black boxes on both sides (each macro is checked on its own with make lec DESIGN=<macro>)
proc sb_lec_black_boxes {} {
    foreach m [env_or MACROS ""] { sb_try add_black_box $m -module -both }
    report_black_box
}

# map key points, compare all of them, report, and print the counts (flow/scripts/lec/lec_result.py reads them)
proc sb_lec_compare {{datapath 0}} {
    report_design_data
    sb_try set_flatten_model -seq_constant   ;# flip-flops stuck at a constant are constants
    set_system_mode lec
    sb_try report_unmapped_points -summary
    if {$datapath} {
        sb_try analyze_datapath -module -verbose
        sb_try analyze_datapath -flowgraph -verbose
    }
    add_compared_points -all
    compare
    if {[get_compare_points -abort -count] > 0} { sb_try analyze_abort -compare }
    sb_try report_compare_data -class nonequivalent -class abort -class notcompared
    report_verification -verbose
    puts "No of compare points = [get_compare_points -count]"
    puts "No of diff points    = [get_compare_points -NONequivalent -count]"
    puts "No of abort points   = [get_compare_points -abort -count]"
    puts "No of unknown points = [get_compare_points -unknown -count]"
}
