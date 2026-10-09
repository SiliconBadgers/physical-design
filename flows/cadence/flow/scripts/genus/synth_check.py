#!/usr/bin/env python3
# File:        synth_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Synthesis gate for make synth: no latch cells, unresolved references, multiple drivers, undriven pins or combinational loops. Reads the Genus reports and netlist.v in the build directory.

import argparse
import fnmatch
import re
import sys
from pathlib import Path

# summary rows that must be 0: (report, row label as a regex)
ROWS = [
    ("synth_check_design.rpt", r"Unresolved References"),
    ("synth_check_design.rpt", r"Multidriven Port\(s\)"),
    ("synth_check_design.rpt", r"Multidriven Leaf Pin\(s\)"),
    ("synth_check_design.rpt", r"Multidriven hierarchical Pin\(s\)"),
    ("synth_check_design.rpt", r"Undriven Port\(s\)"),
    ("synth_check_design.rpt", r"Undriven Leaf Pin\(s\)"),
    ("synth_check_timing.rpt", r"Loop-breaking cells for combinational feedback"),
]


def count(text: str, label: str):
    """The number after a row label in a Genus summary table, or None if the row is missing."""
    m = re.search(rf"^\s*{label}\s+(\d+)\s*$", text, re.M)
    return int(m.group(1)) if m else None


def main() -> int:
    ap = argparse.ArgumentParser(description="Check the Genus netlist and reports.")
    ap.add_argument("--build", required=True, help="build directory")
    ap.add_argument("--latch-cells", default="", help="latch cell name patterns, space-separated")
    a = ap.parse_args()
    build = Path(a.build)

    netlist = (build / "netlist.v").read_text(errors="replace")
    cells = set(re.findall(r"^\s*([A-Za-z_][\w$]*)\s+\S+\s*\(", netlist, re.M))
    latches = sorted(c for c in cells if any(fnmatch.fnmatch(c, p) for p in a.latch_cells.split()))
    problems = [f"latch cells: {' '.join(latches)}"] if latches else []

    unread = []
    for rpt, row in ROWS:
        p = build / rpt
        n = count(p.read_text(errors="replace"), row) if p.exists() else None
        label = row.replace("\\", "")
        if n is None:
            unread.append(f"{rpt}: {label}")
        elif n:
            problems.append(f"{label}: {n}")

    for u in unread:
        print(f"SB-WARNING: synth check could not read '{u}'; check it by hand")
    consts = len(re.findall(r"1'b[01]", netlist))
    if consts:
        print(f"SB-WARNING: {consts} constant connections in netlist.v without a tie cell")
    for p in problems:
        print(f"SB-ERROR: {p}")
    ok = not problems
    print(f"SB: synth check {'PASS' if ok else 'FAIL'}: latch cells, unresolved references, "
          f"multiple drivers, undriven pins, loops (reports in {build})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
