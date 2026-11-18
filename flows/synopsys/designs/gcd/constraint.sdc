# File:        constraint.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Timing constraints for gcd, read by Design Compiler, IC Compiler II and PrimeTime. Adapted from OpenROAD-flow-scripts (BSD-3).

# 6.2 ns (Track A: 6.0 ns): signs off at tt and ss; 6.0 ns closes ss by only about 5 ps (track/README.md, Status)
set clk_period 6.2
create_clock -name core_clock -period $clk_period [get_ports clk]
set_input_delay  [expr {0.20 * $clk_period}] -clock core_clock [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {0.20 * $clk_period}] -clock core_clock [all_outputs]

# clk comes from a small clock buffer, as from a clock pad or generator, so the clock tree (not the port) drives the
# 34 flip-flops; with no driving cell the port drives them ideally and CTS inserts no buffer
set_driving_cell -lib_cell sky130_fd_sc_hd__clkbuf_2 -pin X [get_ports clk]
