# File:        synth.sdc
# Author:      Isaac Hagedorn
# Date:        2026-11-17
# Description: Synthesis constraints for gcd in the PPA flow (flows/ppa). CLOCK_NS on the make line sets clk_period.

if {![info exists clk_period]} { set clk_period 6.2 }
create_clock -name core_clock -period $clk_period [get_ports clk]
set_input_delay  [expr {0.20 * $clk_period}] -clock core_clock [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {0.20 * $clk_period}] -clock core_clock [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__clkbuf_2 -pin X [get_ports clk]
