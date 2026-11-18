#!/bin/bash
# File:        drc.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: KLayout DRC of a GDS with the open sky130hd rule deck. Usage: drc.sh <gds> <report.lyrdb> <deck.lydrc>; prints the number of violations.
set -euo pipefail

gds=$1       # layout to check
report=$2    # marker database; open it in KLayout over the GDS
deck=$3      # rule deck

"${KLAYOUT:-klayout}" -b -rd in_gds="$gds" -rd report_file="$report" -r "$deck"
count=$(grep -c '<value>' "$report" || true)
echo "SB: KLayout DRC: $count violation(s) -> $report"
