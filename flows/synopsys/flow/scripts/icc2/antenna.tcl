# File:        antenna.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Antenna rules for IC Compiler II, from the antenna tables in the sky130 tech LEF. Sky130 limits the side area of each layer on its own (not summed over layers).

# Mode 3: side-wall area of one layer / gate area. Diode mode 2: a diode raises the limit.
define_antenna_rule -mode 3 -diode_mode 2 -metal_ratio 0 -cut_ratio 0

# -ratio: limit without a diode. -diode_ratio {v0 v1 v2 v3}: with diode area d > v0, limit = (d + v1) * v2 + v3
define_antenna_layer_rule -mode 3 -layer li1 -ratio 75 -diode_ratio {0.0125 0 450 75}
foreach layer {met1 met2 met3 met4 met5} {
    define_antenna_layer_rule -mode 3 -layer $layer -ratio 400 -diode_ratio {0.0125 0 400 2600}
}
define_antenna_layer_rule -mode 3 -layer mcon -ratio 3 -diode_ratio {0.0125 0 18 3}
foreach layer {via via2 via3 via4} {
    define_antenna_layer_rule -mode 3 -layer $layer -ratio 6 -diode_ratio {0.0125 0 36 6}
}
