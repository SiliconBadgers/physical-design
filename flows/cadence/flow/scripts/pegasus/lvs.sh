#!/usr/bin/env bash
# File:        lvs.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Runs Pegasus LVS: layout (GDS) against the schematic (cell CDL and the Verilog netlist). Usage: lvs.sh <deck> <gds> <top cell> <run dir> <file.cdl|netlist.v>...
#              Env: PEGASUS (command), NCPU.
set -euo pipefail

deck=$(realpath "$1")
gds=$(realpath "$2")
top=$3
run=$4
shift 4
cdl=()
verilog=()
for f in "$@"; do
    case $f in
        *.cdl) cdl+=("$(realpath "$f")") ;;
        *)     verilog+=("$(realpath "$f")") ;;
    esac
done
read -ra pegasus <<< "${PEGASUS:-pegasus}"

mkdir -p "$run"
cd "$run"

# control file: the schematic (cell CDL first, then the Verilog netlist), the layout, and the reports
{
    for f in "${cdl[@]}"; do echo "schematic_path \"$f\" cdl;"; done
    for f in "${verilog[@]}"; do
        echo "schematic_path \"$f\" verilog -keep_backslash -detect_buses -check_inconsistent_instances -ignore_instances_with_missing_cell_master;"
    done
    cat <<EOF
schematic_primary $top;
layout_path "$gds";
layout_primary $top;
lvs_power_name VDD;
lvs_ground_name VSS;
lvs_find_shorts yes;
lvs_report_opt S;
results_db -erc "$top.erc_errors.ascii" -ascii;
report_summary -erc "$top.erc.sum" -replace;
lvs_report_file "$top.lvs.rpt";
EOF
} > pegasuslvsctl

"${pegasus[@]}" -lvs -dp "${NCPU:-4}" -license_dp_continue -automatch -check_schematic \
    -control pegasuslvsctl -log_dir logs -ui_data "$deck"

echo "LVS report: $PWD/$top.lvs.rpt"
