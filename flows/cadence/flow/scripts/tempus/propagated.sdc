# File:        propagated.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Propagated clocks for sign-off timing of the routed netlist (the design SDC has ideal clocks). Read after the design SDC in finish.
set_propagated_clock [all_clocks]
