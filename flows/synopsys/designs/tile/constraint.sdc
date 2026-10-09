# File:        constraint.sdc
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Timing constraints for sb_systolic_tile at 65 MHz, read by Design Compiler, IC Compiler II and PrimeTime.

set clk_period [expr {1000.0 / 65}]   ;# 65 MHz
create_clock -name clk -period $clk_period [get_ports clk]
set_clock_uncertainty -setup [expr {0.10 * $clk_period}] [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]

# Every input except clk and rst_n
set data_inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_input_delay  [expr {0.30 * $clk_period}] -clock clk $data_inputs
set_output_delay [expr {0.30 * $clk_period}] -clock clk [all_outputs]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $data_inputs
set_load [expr {4 * 0.0024}] [all_outputs]   ;# buf_4 pin A = 0.0024 pF (tt Liberty)
set_max_fanout 16 [current_design]

# cfg_k_len is stable 2 cycles before use
set_multicycle_path -setup 2 -from [get_ports cfg_k_len*]
set_multicycle_path -hold 1  -from [get_ports cfg_k_len*]

# rst_n is asynchronous; the tile synchronizes it internally
set_false_path -from [get_ports rst_n]
