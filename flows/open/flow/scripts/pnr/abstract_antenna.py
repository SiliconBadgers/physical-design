#!/usr/bin/env python3
# File:        abstract_antenna.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Adds ANTENNAGATEAREA and ANTENNADIFFAREA to each pin of an abstract LEF: the gate and diffusion area its net reaches inside the block. Without them a parent design cannot check or repair antennas on wires into the block.
import argparse
import re
from pathlib import Path


def cell_antenna(lefs: list[str]) -> dict[tuple[str, str], tuple[float, float]]:
    """(cell, pin) -> (gate area, diff area) from the cell LEFs."""
    out = {}
    for lef in lefs:
        cell = pin = None
        for line in Path(lef).read_text(errors="replace").splitlines():
            t = line.split()
            if not t:
                continue
            if t[0] == "MACRO":
                cell = t[1]
            elif t[0] == "PIN" and cell:
                pin = t[1]
                out.setdefault((cell, pin), (0.0, 0.0))
            elif t[0] == "END" and len(t) > 1 and t[1] == pin:
                pin = None
            elif pin and t[0] in ("ANTENNAGATEAREA", "ANTENNADIFFAREA"):
                g, d = out[(cell, pin)]
                v = float(t[1])
                out[(cell, pin)] = (g + v, d) if t[0] == "ANTENNAGATEAREA" else (g, d + v)
    return out


def def_sections(text: str, name: str) -> list[str]:
    """Statements ('- ...;') of one DEF section."""
    m = re.search(rf"^{name} \d+ ;(.*?)^END {name}", text, re.M | re.S)
    return [s.strip() for s in m.group(1).split(";") if s.strip().startswith("-")] if m else []


def port_areas(def_file: str, cells: dict) -> dict[str, tuple[float, float]]:
    """Port name -> summed (gate, diff) area of the cell pins on its net."""
    text = Path(def_file).read_text()
    master = {}
    for s in def_sections(text, "COMPONENTS"):
        t = s.split()
        master[t[1]] = t[2]
    areas = {}
    for s in def_sections(text, "NETS"):
        conns = re.findall(r"\(\s*(\S+)\s+(\S+)\s*\)", s.split("+")[0])
        ports = [p for i, p in conns if i == "PIN"]
        if not ports:
            continue
        g = d = 0.0
        for inst, pin in conns:
            if inst != "PIN" and inst in master:
                cg, cd = cells.get((master[inst], pin), (0.0, 0.0))
                g, d = g + cg, d + cd
        for p in ports:
            areas[p.replace("\\", "")] = (g, d)
    return areas


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lef", required=True, help="abstract LEF, updated in place")
    ap.add_argument("--def", dest="def_file", required=True, help="the block's final DEF")
    ap.add_argument("--cell-lefs", nargs="+", required=True)
    a = ap.parse_args()

    areas = port_areas(a.def_file, cell_antenna(a.cell_lefs))
    # antenna statements go after the pin's PORT blocks, just before END <pin>
    out, pin, raw, added = [], None, None, 0
    for line in Path(a.lef).read_text().splitlines():
        t = line.split()
        if len(t) == 2 and t[0] == "PIN":
            raw, pin = t[1], t[1].replace("\\", "")
        elif pin and t == ["END", raw]:
            g, d = areas.get(pin, (0.0, 0.0))
            indent = line[:len(line) - len(line.lstrip())] + "  "
            if g > 0:
                out.append(f"{indent}ANTENNAGATEAREA {g:.4f} ;")
            if d > 0:
                out.append(f"{indent}ANTENNADIFFAREA {d:.4f} ;")
            added += (g > 0) + (d > 0)
            pin = None
        out.append(line)
    Path(a.lef).write_text("\n".join(out) + "\n")
    print(f"abstract_antenna: {added} antenna lines on {len(areas)} pins of {a.lef}")


if __name__ == "__main__":
    main()
