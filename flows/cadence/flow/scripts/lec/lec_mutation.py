#!/usr/bin/env python3
# File:        lec_mutation.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Checks that LEC can still fail: breaks the revised netlist of each Conformal step (swaps the D inputs of two flip-flops, turns a NAND2 into an AND2) and expects non-equivalent points.
#              Run by make lec-mutation from the build directory with lec.env sourced.
import argparse
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

from lec_result import counts

# one cell instance: type, name (plain or escaped), pin list; Genus writes ".A (n_1)", Innovus ".A(n_1)"
CELL = re.compile(r"^[ \t]*([A-Za-z_]\w*)\s+(\\\S+|[A-Za-z_][\w$]*)\s*\((.*?)\)\s*;", re.M | re.S)
MODULE = re.compile(r"^[ \t]*module\b.*?^[ \t]*endmodule\b", re.M | re.S)
CONST = re.compile(r"\d*'[bhdBHD][0-9a-fA-FxXzZ_]+")
# a log file set in a dofile (the one Genus wrote)
LOGFILE = re.compile(r"^(\s*set[_ ]log[_ ]file\s+)(\S+)", re.M | re.I)
# sky130_scl_9T: flip-flop pins; NAND2X<n> -> AND2X<n> with the same pins Y, A, B (AND2 comes in X1 and X2)
FF_D, FF_Q = "D", ("Q", "QN")
NAND2 = re.compile(r"NAND2X(\d+)")
AND2 = {"1": "AND2X1", "2": "AND2X2"}


def pin(pins: str, name: str) -> str | None:
    """Net on a pin ("" if unconnected), or None if the cell has no such pin."""
    m = re.search(rf"\.{name}\s*\(\s*([^()]*?)\s*\)", pins)
    return m.group(1) if m else None


def set_pin(cell: str, name: str, net: str) -> str:
    net += " " if net.startswith("\\") else ""   # an escaped name ends at white space
    return re.sub(rf"(\.{name}\s*\(\s*)[^()]*?(\s*\))", lambda m: m.group(1) + net + m.group(2), cell, count=1)


def related(x: str, y: str) -> bool:
    """Same net, or one named after the other (a buffered copy, e.g. FE_OFN3_n_12 and n_12)."""
    return x in y or y in x


def swap_d(text: str) -> str:
    """Swap the D nets of two flip-flops in the same module whose D nets differ and are not constants."""
    best = []
    for mod in MODULE.finditer(text):
        ffs = [c for c in CELL.finditer(text, mod.start(), mod.end())
               if pin(c.group(3), FF_D) and any(pin(c.group(3), q) is not None for q in FF_Q)
               and not CONST.fullmatch(pin(c.group(3), FF_D))]
        if len(ffs) > len(best):
            best = ffs
    i = len(best) // 3
    a = best[i] if best else None
    b = next((c for c in best[i + 1:] + best[:i]
              if a and not related(pin(c.group(3), FF_D), pin(a.group(3), FF_D))), None)
    if b is None:
        sys.exit("lec-mutation: no module with two flip-flops on different D nets")
    if b.start() < a.start():
        a, b = b, a
    d_a, d_b = pin(a.group(3), FF_D), pin(b.group(3), FF_D)
    print(f"lec-mutation: swap D of {a.group(2)} and {b.group(2)}")
    return (text[:a.start()] + set_pin(a.group(0), FF_D, d_b) + text[a.end():b.start()]
            + set_pin(b.group(0), FF_D, d_a) + text[b.end():])


def nand_to_and(text: str) -> str:
    """Turn the first NAND2 into an AND2 (same inputs, inverted output)."""
    c = next((c for c in CELL.finditer(text) if NAND2.fullmatch(c.group(1))), None)
    if c is None:
        sys.exit("lec-mutation: no NAND2 cell")
    new = c.group(0).replace(c.group(1), AND2.get(NAND2.fullmatch(c.group(1)).group(1), "AND2X2"), 1)
    print(f"lec-mutation: {c.group(2)} {c.group(1)} -> {new.split()[0]}")
    return text[:c.start()] + new + text[c.end():]


def main() -> None:
    ap = argparse.ArgumentParser(description="LEC must fail on broken netlists.")
    ap.add_argument("--check", nargs=3, action="append", required=True, metavar=("STEP", "DOFILE", "NETLIST"),
                    help="LEC step, its dofile, and the revised netlist it reads")
    ap.add_argument("--work", required=True)
    ap.add_argument("--cmd", default="lec -xl -nogui", help="Conformal command with its options")
    a = ap.parse_args()

    work = Path(a.work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    missed = 0
    for step, dofile, netlist in a.check:
        text = Path(netlist).read_text()
        do = Path(dofile).read_text()
        if netlist not in do and "LEC_REVISED" not in do:
            sys.exit(f"lec-mutation: {dofile} reads neither {netlist} nor LEC_REVISED")
        for kind, mutate in (("swap_d", swap_d), ("nand_and", nand_to_and)):
            name = f"lec_{step}_{kind}"
            mutant, log = work / f"{name}.v", work / f"{name}.conformal.log"
            mutant.write_text(mutate(text))
            # the dofile with the mutant as revised netlist (Genus's names the file, ours read LEC_REVISED)
            (work / f"{name}.do").write_text(LOGFILE.sub(lambda m: m.group(1) + str(log), do.replace(netlist, str(mutant))))
            env = dict(os.environ, LEC_REVISED=str(mutant), LEC_LOG=str(log))
            with open(work / f"{name}.log", "w") as f:
                subprocess.run([*shlex.split(a.cmd), "-dofile", str(work / f"{name}.do")], stdin=subprocess.DEVNULL,
                               stdout=f, stderr=subprocess.STDOUT, env=env)
            c = counts((work / f"{name}.log").read_text(errors="replace"))
            caught = c is not None and c["diff"] > 0
            missed += not caught
            result = "no result" if c is None else f"{c['diff']} non-equivalent"
            print(f"lec-mutation: {name}: {result} -> {'caught' if caught else 'LEC MISSED IT'} ({work / name}.log)")
    print(f"LEC_MUTATION: {'PASS' if not missed else 'FAIL'} ({2 * len(a.check) - missed}/{2 * len(a.check)} caught)")
    sys.exit(1 if missed else 0)


if __name__ == "__main__":
    main()
