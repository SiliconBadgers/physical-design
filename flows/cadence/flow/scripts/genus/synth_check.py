#!/usr/bin/env python3
# File:        synth_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Synthesis gate for make synth: no latch cells, unresolved references, multiple drivers, undriven pins or combinational loops. Reads the Genus reports and netlist.v in the build directory.
#              Fails when it cannot read a report row. A synthesis wrapper that writes no Genus reports (a stand-in) writes
#              synth_check.skip (one line: why) next to netlist.v; the report rows are then SKIPPED, and netlist.v is still checked.

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


# written by a synthesis wrapper that writes no Genus reports; make synth deletes it before each run
SKIP_FILE = "synth_check.skip"


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

    if not (build / "netlist.v").is_file():
        print(f"SB-ERROR: no netlist.v in {build}")
        print("SB: synth check FAIL")
        return 1
    netlist = (build / "netlist.v").read_text(errors="replace")
    cells = set(re.findall(r"^\s*([A-Za-z_][\w$]*)\s+\S+\s*\(", netlist, re.M))
    latches = sorted(c for c in cells if any(fnmatch.fnmatch(c, p) for p in a.latch_cells.split()))
    problems = [f"latch cells: {' '.join(latches)}"] if latches else []
    consts = len(re.findall(r"1'b[01]", netlist))
    if consts:
        print(f"SB-WARNING: {consts} constant connections in netlist.v without a tie cell")

    skip = build / SKIP_FILE
    if skip.is_file():
        why = " ".join(skip.read_text(errors="replace").split()) or "no reason given"
        for p in problems:
            print(f"SB-ERROR: {p}")
        if problems:
            print("SB: synth check FAIL")
            return 1
        print(f"SB: synth check SKIPPED ({SKIP_FILE}: {why}): netlist.v has no latch cells; unresolved references, "
              "multiple drivers, undriven pins and loops not checked")
        return 0

    for rpt, row in ROWS:
        p = build / rpt
        n = count(p.read_text(errors="replace"), row) if p.exists() else None
        label = row.replace("\\", "")
        if n is None:
            problems.append(f"could not read '{rpt}: {label}' (missing report, or a row label this release words otherwise)")
        elif n:
            problems.append(f"{label}: {n}")

    for p in problems:
        print(f"SB-ERROR: {p}")
    ok = not problems
    print(f"SB: synth check {'PASS' if ok else 'FAIL'}: latch cells, unresolved references, "
          f"multiple drivers, undriven pins, loops (reports in {build})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
