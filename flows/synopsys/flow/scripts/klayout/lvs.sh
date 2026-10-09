#!/bin/bash
# File:        lvs.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: KLayout LVS of the final GDS against the IC Compiler II LVS netlist, with the open sky130hd deck. Usage: lvs.sh <top> <netlist.v> <gds> <cells.cdl> <deck.lylvs>; run it from the build folder.
set -euo pipefail

top=$1        # top cell
netlist=$2    # Verilog netlist with power pins and physical cells (final_lvs.v)
gds=$3        # layout
cell_cdl=$4   # cell subcircuits
deck=$5       # LVS deck
here=$(cd "$(dirname "$0")" && pwd)

# schematic side: the netlist as one CDL subcircuit, then the cells
python3 "$here/v2cdl.py" "$netlist" --top "$top" --cdl "$cell_cdl" -o final.cdl
cat final.cdl "$cell_cdl" > final_concat.cdl

# layout side: the GDS; KLayout extracts it and compares
"${KLAYOUT:-klayout}" -b -rd in_gds="$gds" -rd cdl_file="$PWD/final_concat.cdl" -rd top_cell="$top" \
    -rd report_file="$PWD/lvs.lvsdb" -rd target_netlist="$PWD/${top}_extracted.cir" \
    -r "$deck" > lvs.log 2>&1 || true

if grep -q 'Netlists match' lvs.log; then
    echo "SB: KLayout LVS: netlists match"
else
    tail -5 lvs.log
    echo "SB: KLayout LVS: netlists DO NOT match. Read lvs.log; open lvs.lvsdb in KLayout over the GDS"
    exit 1
fi
