#!/usr/bin/env bash
# File:        drc.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Runs Pegasus DRC on a GDS and writes the violation count to a file. Usage: drc.sh <deck> <gds> <top cell> <run dir> <count file>.
#              Env: PEGASUS (command), NCPU, DRC_DENSITY (1 = also check metal density).
set -euo pipefail

rules=$(realpath "$1")
gds=$(realpath "$2")
top=$3
run=$4
count=$(realpath -m "$5")
PEGASUS_DRC=$(dirname "$rules")   # the deck includes $PEGASUS_DRC/Include/*.pvl
export PEGASUS_DRC
read -ra pegasus <<< "${PEGASUS:-pegasus}"

mkdir -p "$run"
cd "$run"

# density rules need metal fill, which this flow does not add: off unless DRC_DENSITY=1
if [ "${DRC_DENSITY:-0}" != 1 ]; then
    printf '#DEFINE NODEN\nInclude %s\n' "$rules" > rules.pvl
    rules=$PWD/rules.pvl
fi

# control file: replaces the deck's input and output lines (layout file, top cell, result files)
cat > pegasusdrcctl <<EOF
layout_path "$gds";
layout_primary $top;
results_db -drc "$top.drc_errors.ascii" -ascii;
report_summary -drc "$top.drc.sum" -replace;
EOF

"${pegasus[@]}" -drc -dp "${NCPU:-4}" -license_dp_continue \
    -control pegasusdrcctl -log_dir logs -ui_data "$rules"

# violation count: the summary total, else the result records in the ASCII database
n=$(grep -aiE 'total drc results generated' "$top.drc.sum" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
[ -n "$n" ] || n=$(grep -cE '^[pe] [0-9]+ [0-9]+' "$top.drc_errors.ascii" 2>/dev/null || true)
echo "${n:-unknown}" > "$count"
echo "DRC summary: $PWD/$top.drc.sum"
