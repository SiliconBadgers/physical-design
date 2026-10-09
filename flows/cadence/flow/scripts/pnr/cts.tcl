# File:        cts.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Clock tree synthesis (CCOpt), then setup and hold repair with real clock arrival times. Writes cts.db.
source $::env(SCRIPTS)/pnr/common.tcl
sb_open place
set out $::env(OUT_DIR)

# cells the clock tree may use (CTS_INV_LIST=none: buffers only)
if {[env_or CTS_BUF_LIST ""] ne ""} { set_db cts_buffer_cells $::env(CTS_BUF_LIST) }
set inverters [env_or CTS_INV_LIST none]
if {$inverters eq "none"} {
    set_db cts_use_inverters false
} else {
    set_db cts_inverter_cells $inverters
}

# clock wires on the clock routing layers (route type used by CTS and the router)
sb_try create_route_type -name clk_route \
    -bottom_preferred_layer $::env(MIN_CLK_ROUTING_LAYER) -top_preferred_layer $::env(MAX_CLK_ROUTING_LAYER)
sb_try set_db cts_route_type_trunk clk_route
sb_try set_db cts_route_type_leaf  clk_route

# build the tree; setup and hold repair unless switched off
create_clock_tree_spec
if {[env_or SKIP_CTS_REPAIR_TIMING 0]} {
    ccopt_design -cts
} else {
    ccopt_design
    opt_design -post_cts -hold
}
sb_propagate

# clock trees (buffers, levels) and skew groups (skew, insertion delay)
sb_try report_clock_trees > $out/cts_clock_trees.rpt
sb_try report_skew_groups > $out/cts_skew_groups.rpt

sb_report cts cts -post_cts 1
sb_save cts
sb_done cts
exit
