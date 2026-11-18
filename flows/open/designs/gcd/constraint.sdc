# File:        constraint.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Timing constraints for gcd. Adapted from OpenROAD-flow-scripts (BSD-3).
current_design gcd

set clk_period 6.0
create_clock -name core_clock -period $clk_period [get_ports clk]
set_input_delay  [expr {0.20 * $clk_period}] -clock core_clock [all_inputs -no_clocks]
set_output_delay [expr {0.20 * $clk_period}] -clock core_clock [all_outputs]
