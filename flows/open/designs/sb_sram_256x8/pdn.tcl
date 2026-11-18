# File:        pdn.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Power grid of the sb_sram_256x8 block: met1 rails and met4 straps (its power pins), no met5. Adapted from the ORFS sky130hd pdn.tcl (BSD-3).
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {VPWR} -power
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {VPB}
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {VGND} -ground
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {VNB}
global_connect

set_voltage_domain -name {CORE} -power {VDD} -ground {VSS}

define_pdn_grid -name {grid} -voltage_domains {CORE} -pins {met4}
add_pdn_stripe -grid {grid} -layer {met1} -width {0.48} -pitch {5.44} -offset {0} -followpins   ;# cell rails
add_pdn_stripe -grid {grid} -layer {met4} -width {1.600} -pitch {27.140} -offset {13.570}       ;# straps, also the macro's power pins
add_pdn_connect -grid {grid} -layers {met1 met4}
