#!/usr/bin/env python3
# File:        compare_orfs.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Runs ORFS place and route on our netlist and SDC with the same floorplan settings. Prints both flows' metrics per stage.
import argparse
import json
import re
import subprocess
from pathlib import Path

# metric (ORFS name) -> label; both flows report these names
METRICS = [
    ("floorplan__design__core__area", "floorplan core area (um2)"),
    ("detailedplace__design__instance__area", "place area (um2)"),
    ("detailedplace__timing__setup__ws", "place setup WS (ns)"),
    ("cts__timing__setup__ws", "cts setup WS (ns)"),
    ("cts__timing__hold__ws", "cts hold WS (ns)"),
    ("cts__clock__skew__setup", "cts skew (ns)"),
    ("globalroute__timing__setup__ws", "grt setup WS (ns)"),
    ("detailedroute__route__wirelength", "route wirelength (um)"),
    ("detailedroute__route__vias", "route vias"),
    ("detailedroute__route__drc_errors", "route DRC errors"),
    ("finish__timing__setup__ws", "finish setup WS (ns)"),
    ("finish__timing__setup__tns", "finish setup TNS (ns)"),
    ("finish__timing__hold__ws", "finish hold WS (ns)"),
    ("finish__design__instance__area", "finish area (um2)"),
    ("finish__design__instance__utilization", "finish utilization"),
]


def load(folder):
    m = {}
    for f in sorted(Path(folder).glob("*.json")):
        try:
            m.update(json.loads(f.read_text()))
        except ValueError:
            pass
    return m


def drc_count(lyrdb):
    p = Path(lyrdb)
    return len(re.findall(r"<value>", p.read_text())) if p.exists() else None


def main():
    ap = argparse.ArgumentParser(description="Compare this flow with ORFS on the same netlist.")
    ap.add_argument("--build", required=True)
    ap.add_argument("--orfs", required=True)
    ap.add_argument("--pdk", required=True, help="platform directory (sky130hd)")
    ap.add_argument("--top", required=True)
    ap.add_argument("--sdc", required=True)
    ap.add_argument("--util", required=True)
    ap.add_argument("--aspect", required=True)
    ap.add_argument("--margin", required=True)
    ap.add_argument("--density", required=True)
    ap.add_argument("--macro-lefs", default="")
    ap.add_argument("--macro-libs", default="")
    ap.add_argument("--macro-gds", default="")
    a = ap.parse_args()

    build = Path(a.build).resolve()
    work = build / "orfs"
    work.mkdir(exist_ok=True)
    cfg = work / "config.mk"
    cfg.write_text(
        f"export DESIGN_NAME = {a.top}\n"
        f"export PLATFORM = sky130hd\n"
        f"export VERILOG_FILES = {build}/netlist.v\n"
        f"export SYNTH_NETLIST_FILES = {build}/netlist.v\n"
        f"export SDC_FILE = {Path(a.sdc).resolve()}\n"
        f"export CORE_UTILIZATION = {a.util}\n"
        f"export CORE_ASPECT_RATIO = {a.aspect}\n"
        f"export CORE_MARGIN = {a.margin}\n"
        f"export PLACE_DENSITY = {a.density}\n"
        f"export ADDITIONAL_LEFS = {a.macro_lefs}\n"
        f"export ADDITIONAL_LIBS = {a.macro_libs}\n"
        f"export ADDITIONAL_GDS = {a.macro_gds}\n"
    )
    log = work / "orfs.log"
    cmd = ["make", "-C", f"{a.orfs}/flow", f"DESIGN_CONFIG={cfg}", f"PLATFORM_DIR={a.pdk}",
           f"WORK_HOME={work}", "finish", "drc"]
    print("ORFS:", " ".join(cmd), f"> {log}")
    with open(log, "w") as f:
        rc = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT).returncode
    if rc:
        print(f"ORFS run failed (rc={rc}); see {log}")

    ours = load(build)
    orfs = load(work / "logs" / "sky130hd" / a.top / "base")
    print(f"\n{'metric':28} {'ours':>12} {'ORFS':>12}")
    for key, label in METRICS:
        print(f"{label:28} {fmt(ours.get(key)):>12} {fmt(orfs.get(key)):>12}")
    print(f"{'KLayout DRC violations':28} {fmt(drc_count(build / 'drc.lyrdb')):>12} "
          f"{fmt(drc_count(work / 'reports' / 'sky130hd' / a.top / 'base' / '6_drc.lyrdb')):>12}")


def fmt(v):
    if v is None:
        return "-"
    return f"{v:.3f}" if isinstance(v, float) else str(v)


if __name__ == "__main__":
    main()
