#!/usr/bin/env python3
# File:        ppa.py
# Author:      Isaac Hagedorn
# Date:        2026-11-17
# Description: Results of the PPA flow.
#              run <run folder> <unit> <effort> <corner>: reads one Design Compiler run (<run folder>/work/reports) into
#              <run folder>/ppa.json; exits 1 if the run failed.
#              table <build folder>: prints every run's ppa.json as one table and writes ppa.md and ppa.csv there.
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

# Power units in report_power, in mW
POWER_UNITS = {"pW": 1e-9, "nW": 1e-6, "uW": 1e-3, "mW": 1.0, "W": 1e3}

# Table columns: key, heading, format
COLUMNS = [
    ("unit", "Unit", "{}"),
    ("effort", "Effort", "{}"),
    ("corner", "Corner", "{}"),
    ("clock_ns", "Clock (ns)", "{:.2f}"),
    ("wns_ns", "Slack (ns)", "{:.3f}"),
    ("fmax_mhz", "Fmax (MHz)", "{:.0f}"),
    ("area_um2", "Area (um2)", "{:.0f}"),
    ("cells", "Cells", "{}"),
    ("power_mw", "Power (mW)", "{:.4f}"),
    ("status", "Status", "{}"),
]
CSV_KEYS = ["unit", "effort", "corner", "clock_ns", "wns_ns", "tns_ns", "fmax_mhz", "area_um2", "comb_area_um2",
            "seq_area_um2", "macro_area_um2", "cells", "latches", "power_mw", "internal_mw", "switching_mw",
            "leakage_mw", "status", "revision"]


def number(text, pattern):
    """First number after a label in a report, or None."""
    m = re.search(pattern + r"\s*([-+\d.eE]+)", text)
    try:
        return float(m.group(1)) if m else None
    except ValueError:
        return None


def power_mw(text, label):
    """A report_power line such as 'Cell Leakage Power = 1.23 nW', in mW, or None."""
    m = re.search(label + r"\s*=\s*([-+\d.eE]+)\s*(pW|nW|uW|mW|W)\b", text)
    return float(m.group(1)) * POWER_UNITS[m.group(2)] if m else None


def read_run(folder, unit, effort, corner):
    """One run's numbers; status 'failed' when the run stopped before the reports."""
    reports = folder / "work" / "reports"
    row = {"unit": unit, "effort": effort, "corner": corner}
    rev = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    row["revision"] = rev.stdout.strip()
    if not (reports / "metrics.txt").is_file():
        row["status"] = "failed"
        return row
    metrics = {}
    for line in (reports / "metrics.txt").read_text().splitlines():
        key, _, value = line.partition(" ")
        try:
            metrics[key] = float(value)
        except ValueError:
            metrics[key] = None   # empty, or INFINITY when nothing is constrained
    area = (reports / "area.rpt").read_text()
    power = (reports / "power.rpt").read_text()
    clock, wns = metrics.get("clock_ns"), metrics.get("wns_ns")
    row.update({
        "clock_ns": clock,
        "wns_ns": wns,
        "tns_ns": metrics.get("tns_ns"),
        "fmax_mhz": 1000.0 / (clock - wns) if clock and wns is not None and clock > wns else None,
        "area_um2": number(area, r"Total cell area:"),
        "comb_area_um2": number(area, r"Combinational area:"),
        "seq_area_um2": number(area, r"Noncombinational area:"),
        "macro_area_um2": number(area, r"Macro/Black Box area:"),
        "cells": int(metrics["cells"]) if metrics.get("cells") is not None else None,
        "latches": int(metrics["latches"]) if metrics.get("latches") is not None else None,
        "internal_mw": power_mw(power, "Cell Internal Power"),
        "switching_mw": power_mw(power, "Net Switching Power"),
        "leakage_mw": power_mw(power, "Cell Leakage Power"),
    })
    parts = [row["internal_mw"], row["switching_mw"], row["leakage_mw"]]
    row["power_mw"] = sum(parts) if None not in parts else None
    if row["latches"]:
        row["status"] = "latches"
    elif wns is None:
        row["status"] = "unconstrained"
    elif wns < 0:
        row["status"] = "timing not met"
    else:
        row["status"] = "met"
    return row


def cell(row, key, fmt):
    value = row.get(key)
    return "-" if value is None else fmt.format(value)


def table(build):
    """Every run under the build folder, as a Markdown table, plus ppa.md and ppa.csv."""
    rows = [json.loads(p.read_text()) for p in sorted(build.glob("*/*/ppa.json"))]
    lines = ["| " + " | ".join(h for _, h, _ in COLUMNS) + " |",
             "|" + "---|" * len(COLUMNS)]
    lines += ["| " + " | ".join(cell(r, k, f) for k, _, f in COLUMNS) + " |" for r in rows]
    text = "\n".join(lines) + "\n"
    (build / "ppa.md").write_text(text)
    with open(build / "ppa.csv", "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_KEYS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(text, end="")
    print(f"{len(rows)} run(s); also in {build / 'ppa.md'} and {build / 'ppa.csv'}")


def main():
    if len(sys.argv) == 6 and sys.argv[1] == "run":
        folder = Path(sys.argv[2])
        folder.mkdir(parents=True, exist_ok=True)
        row = read_run(folder, *sys.argv[3:6])
        (folder / "ppa.json").write_text(json.dumps(row, indent=2) + "\n")
        if row["status"] == "failed":
            log = folder / "work" / "reports" / "synth.log"
            errors = [l for l in log.read_text(errors="replace").splitlines() if "Error" in l or "ERROR" in l] \
                if log.is_file() else []
            print(f"{row['unit']} FAILED -- the run stopped before the reports (FuseSoC messages above; Design Compiler log: {log})")
            for line in errors[-5:]:
                print("  " + line)
            return 1
        print(f"{row['unit']} {row['effort']} {row['corner']}: " + ", ".join(
            f"{h} {cell(row, k, f)}" for k, h, f in COLUMNS[3:]))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "table":
        table(Path(sys.argv[2]))
        return 0
    print("usage: ppa.py run <run folder> <unit> <effort> <corner> | ppa.py table <build folder>")
    return 2


if __name__ == "__main__":
    sys.exit(main())
