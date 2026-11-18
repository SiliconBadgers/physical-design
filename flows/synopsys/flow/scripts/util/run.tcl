# File:        run.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Runs one flow script (SB_SCRIPT) in any Synopsys shell and exits. Writes OUT_DIR/<SB_STAGE>.done only when the script ends without a Tcl error.

if {[catch {source -echo $::env(SB_SCRIPT)} msg]} {
    puts "Error: $msg"
    puts "Error: stage $::env(SB_STAGE) stopped. Read the first Error above; the Tcl trace follows."
    puts $::errorInfo
    exit 1
}
close [open $::env(OUT_DIR)/$::env(SB_STAGE).done w]
exit 0
