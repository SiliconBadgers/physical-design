#!/bin/bash
# File:        run_starrc.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: StarRC extraction of the routed design (final.def) into final.spef; hard macros are black boxes from their LEF. Inputs are environment variables from pnr.env, written by the Makefile; StarRC works in <build>/starrc/.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$OUT_DIR
dir=$out/starrc
mkdir -p "$dir"

# LEF layer name -> ITF layer name (the same names in sky130)
cat > "$dir/layers.map" <<MAP
conducting_layers
li1  li1
met1 met1
met2 met2
met3 met3
met4 met4
met5 met5
via_layers
licon licon
mcon  mcon
via   via
via2  via2
via3  via3
via4  via4
MAP

sed -e "s|@TOP@|$TOP|" \
    -e "s|@DEF@|$out/final.def|" \
    -e "s|@LEFS@|$TECH_LEF $CELL_LEF${MACRO_LEFS:+ $MACRO_LEFS}|" \
    -e "s|@NXTGRD@|$NXTGRD|" \
    -e "s|@MAP@|$dir/layers.map|" \
    -e "s|@SPEF@|$out/final.spef|" \
    -e "s|@SUMMARY@|summary.txt|" \
    -e "s|@STAR_DIR@|$dir/star|" \
    -e "s|@CORES@|${CORES:-4}|" \
    "$here/starrc.cmd.in" > "$dir/starrc.cmd"

rm -f "$out/final.spef"
# StarRC runs in starrc/; SUMMARY_FILE must be a path relative to it (SX-3978)
cd "$dir"
"${STARRC:-StarXtract}" -clean starrc.cmd
test -s "$out/final.spef" || { echo "Error: StarRC wrote no $out/final.spef"; exit 1; }
echo "SB: extraction done: $out/final.spef"
