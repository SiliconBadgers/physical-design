# File:        constraint.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Timing constraints for the sb_sram_256x8 block on sky130_scl_9T (plain SDC).
current_design sb_sram_256x8

set clk_period 10.0
create_clock -name clk -period $clk_period [get_ports clk]
set_input_delay  [expr {0.30 * $clk_period}] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {0.30 * $clk_period}] -clock clk [all_outputs]
