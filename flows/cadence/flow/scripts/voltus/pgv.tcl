# File:        pgv.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Builds the Voltus tech-only power-grid view (PGV) of sky130_scl_9T into PGV_DIR/techonly.cl. The PDK ships none; make builds it once.
source $::env(SCRIPTS)/util/sb_util.tcl
set_multi_cpu_usage -local_cpu [env_or NCPU 4]

read_physical -lef [concat $::env(TECH_LEF) $::env(CELL_LEF)]

# tech-only view: metal and via resistance from the Quantus tech file, cell power pins from the LEF
# (no -lef_layer_map: Voltus maps the LEF layers to the Quantus layers itself; it does not read the CCL map Innovus needs)
set_pg_library_mode -cell_type techonly \
    -extraction_tech_file $::env(QRC_TECH) \
    -default_power_voltage $::env(VDD_V)
write_pg_library -out_dir $::env(PGV_DIR)

sb_done pgv
exit
