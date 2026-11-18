#!/usr/bin/env python3
# File:        lec_mutation.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Checks that LEC can still fail: breaks the gate netlist of each LEC step with Track A's mutations (swaps two flip-flop D inputs, turns a NAND2 into an AND2). Formality must report a failed verification for every mutant.
import argparse
import re
import subprocess
import sys
from pathlib import Path

# one cell instance: type, name, pin list; spaces around the parentheses are optional (IC Compiler II writes ".A ( n1 ) ) ;")
CELL = re.compile(r"^\s*(\w+)\s+(\S+)\s*\((.*?)\)\s*;", re.M | re.S)


def pin(pins: str, name: str) -> str | None:
    m = re.search(rf"\.{name}\s*\(([^()]*)\)", pins)
    return m.group(1) if m else None


def set_pin(cell: str, name: str, net: str) -> str:
    """The cell text with pin `name` connected to `net`."""
    return re.sub(rf"(\.{name}\s*\()[^()]*(\))", lambda m: m.group(1) + net + m.group(2), cell, count=1)


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
    new_a = set_pin(a.group(0), "D", d_b)
    new_b = set_pin(b.group(0), "D", d_a)
    print(f"lec-mutation: swap D of {a.group(2)} and {b.group(2)}")
    return text[:a.start()] + new_a + text[a.end():b.start()] + new_b + text[b.end():]


def nand_to_and(text: str) -> str:
    """Turn one NAND2 into an AND2 (same inputs, inverted output)."""
    c = next((c for c in CELL.finditer(text) if re.search(r"__nand2_\d$", c.group(1))), None)
    if c is None:
        sys.exit("lec-mutation: no nand2 cell")
    new = re.sub(r"\.Y(\s*\()", r".X\1", re.sub(r"__nand2_(\d)", r"__and2_\1", c.group(0), count=1))
    print(f"lec-mutation: {c.group(2)} nand2 -> and2")
    return text[:c.start()] + new + text[c.end():]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", nargs=2, action="append", required=True, metavar=("ENV", "NETLIST"),
                    help="lec_<step>.env and the gate netlist it names as IMPL_NETLIST")
    ap.add_argument("--work", required=True)
    ap.add_argument("--cmd", required=True, help="Formality command, run after sourcing the env file")
    a = ap.parse_args()

    work = Path(a.work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    missed = 0
    for env, netlist in a.check:
        cfg = Path(env).read_text()
        text = Path(netlist).read_text()
        impl = f"IMPL_NETLIST='{netlist}'"
        if impl not in cfg:
            sys.exit(f"lec-mutation: {env} does not set {impl}")
        for kind, mutate in (("swap_d", swap_d), ("nand_and", nand_to_and)):
            name = f"{Path(env).stem}_{kind}"
            (work / f"{name}.v").write_text(mutate(text))
            # same inputs, the mutant as the implementation; reports go to the work folder
            (work / f"{name}.env").write_text(cfg.replace(impl, f"IMPL_NETLIST='{work / name}.v'")
                                              + f"export OUT_DIR='{work}' SB_STAGE='{name}'\n")
            log = work / f"{name}.log"
            with open(log, "w") as f:
                subprocess.run(["bash", "-c", f"source {name}.env && {a.cmd}"], cwd=work, stdout=f,
                               stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
            failed = re.search(r"^\s*Verification FAILED", log.read_text(), re.M) is not None
            missed += not failed
            print(f"lec-mutation: {name}: LEC says {'FAIL -> good' if failed else 'not FAIL -> LEC MISSED IT'}")
    print(f"LEC_MUTATION: {'PASS' if not missed else 'FAIL'} ({2 * len(a.check) - missed}/{2 * len(a.check)} caught)")
    sys.exit(1 if missed else 0)


if __name__ == "__main__":
    main()
