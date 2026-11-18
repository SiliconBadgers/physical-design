#!/usr/bin/env python3
# File:        lec_mutation.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Checks that LEC can still fail: breaks the gate netlist of each eqy config (swaps two flip-flop D inputs, turns a NAND2 into an AND2) and expects eqy to report FAIL.
import argparse
import re
import shlex
import subprocess
import sys
from pathlib import Path

# one cell instance (Yosys or OpenROAD netlist): type, name, pin list
CELL = re.compile(r"^\s+(\w+) (\S+) \((.*?)\);", re.M | re.S)


def pin(pins: str, name: str) -> str | None:
    m = re.search(rf"\.{name}\(([^()]*)\)", pins)
    return m.group(1) if m else None


def swap_d(text: str) -> str:
    """Swap the D nets of two flip-flops whose D is not a constant."""
    ffs = [c for c in CELL.finditer(text)
           if pin(c.group(3), "D") and (pin(c.group(3), "Q") or pin(c.group(3), "Q_N"))
           and not re.fullmatch(r"\s*\d+'[bh][0-9a-fx]+\s*", pin(c.group(3), "D"))]
    da = {pin(c.group(3), "D").strip() for c in ffs}
    if len(ffs) < 2 or len(da) < 2:
        sys.exit("lec-mutation: fewer than two flip-flops with different D nets")
    a = ffs[len(ffs) // 3]
    b = next(c for c in ffs[len(ffs) // 3 + 1:] + ffs if pin(c.group(3), "D") != pin(a.group(3), "D"))
    if b.start() < a.start():
        a, b = b, a
    d_a, d_b = pin(a.group(3), "D"), pin(b.group(3), "D")
    new_a = a.group(0).replace(f".D({d_a})", f".D({d_b})")
    new_b = b.group(0).replace(f".D({d_b})", f".D({d_a})")
    print(f"lec-mutation: swap D of {a.group(2)} and {b.group(2)}")
    return text[:a.start()] + new_a + text[a.end():b.start()] + new_b + text[b.end():]


def nand_to_and(text: str) -> str:
    """Turn one NAND2 into an AND2 (same inputs, inverted output)."""
    c = next((c for c in CELL.finditer(text) if re.search(r"__nand2_\d$", c.group(1))), None)
    if c is None:
        sys.exit("lec-mutation: no nand2 cell")
    new = re.sub(r"__nand2_(\d)", r"__and2_\1", c.group(0), count=1).replace(".Y(", ".X(")
    print(f"lec-mutation: {c.group(2)} nand2 -> and2")
    return text[:c.start()] + new + text[c.end():]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", nargs=2, action="append", required=True, metavar=("EQY", "NETLIST"),
                    help="eqy config and the gate netlist it reads")
    ap.add_argument("--work", required=True)
    ap.add_argument("--cmd", default="eqy", help="eqy command with its options")
    a = ap.parse_args()

    work = Path(a.work)
    work.mkdir(parents=True, exist_ok=True)
    missed = 0
    for eqy, netlist in a.check:
        cfg = Path(eqy).read_text()
        text = Path(netlist).read_text()
        if netlist not in cfg:
            sys.exit(f"lec-mutation: {eqy} does not read {netlist}")
        for kind, mutate in (("swap_d", swap_d), ("nand_and", nand_to_and)):
            name = f"{Path(eqy).stem}_{kind}"
            (work / f"{name}.v").write_text(mutate(text))
            (work / f"{name}.eqy").write_text(cfg.replace(netlist, str((work / f"{name}.v").resolve())))
            log = work / f"{name}.log"
            with open(log, "w") as f:
                subprocess.run([*shlex.split(a.cmd), "-f", "-d", name, f"{name}.eqy"], cwd=work, stdout=f,
                               stderr=subprocess.STDOUT)
            failed = "DONE (FAIL" in log.read_text()
            missed += not failed
            print(f"lec-mutation: {name}: LEC says {'FAIL -> good' if failed else 'PASS -> LEC MISSED IT'}")
    print(f"LEC_MUTATION: {'PASS' if not missed else 'FAIL'} ({2 * len(a.check) - missed}/{2 * len(a.check)} caught)")
    sys.exit(1 if missed else 0)


if __name__ == "__main__":
    main()
