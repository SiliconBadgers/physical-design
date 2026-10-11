# File:        constraint.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Timing constraints for gcd, read by Design Compiler, IC Compiler II and PrimeTime. Adapted from OpenROAD-flow-scripts (BSD-3).

# 6.2 ns: the full-signoff run (setup at ss, hold at ff) missed 6.0 ns (Track A's tt clock) by 0.11 ns at ss
set clk_period 6.2
create_clock -name core_clock -period $clk_period [get_ports clk]
set_input_delay  [expr {0.20 * $clk_period}] -clock core_clock [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {0.20 * $clk_period}] -clock core_clock [all_outputs]
