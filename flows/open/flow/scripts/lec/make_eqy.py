#!/usr/bin/env python3
# File:        make_eqy.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Fills in eqy.template for one design and platform (called by make lec). Runs Yosys on the RTL to find output ports, multi-bit registers and kept modules.

import argparse
import re
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path

def analyze_gold(yosys: str, gold_read: str, top: str) -> tuple[list[str], dict[str, int], str]:
    """Return (output bits, output port widths, flattened gold RTLIL)."""
    with tempfile.TemporaryDirectory() as tmp:
        all_f, il_f = Path(tmp, "all.txt"), Path(tmp, "gold.il")
        script = "\n".join([
            gold_read,
            f"prep -top {top}",
            "flatten",
            "memory_map",
            "opt_clean",
            # same optimizations as the [gold] section of eqy.template
            "opt -keepdc",
            "opt_dff -sat",
            "opt -keepdc",
            "opt_dff -sat",
            "opt -keepdc",
            "opt_merge",
            "opt_clean",
            f"write_rtlil {il_f}",
            "splitnets -ports",
            f"cd {top}",                    # the top module's outputs only
            f"tee -q -o {all_f} select -list o:*",
        ])
        ys = Path(tmp, "find_outputs.ys")
        ys.write_text(script + "\n")
        subprocess.run([yosys, "-q", "-s", str(ys)], check=True)

        def names(f: Path) -> list[str]:
            # select -list prints "<module>/<wire>"
            return [ln.split("/", 1)[1] for ln in f.read_text().split() if "/" in ln]

        outputs = names(all_f)
        widths: dict[str, int] = defaultdict(int)
        for n in outputs:
            widths[re.sub(r"\[\d+\]$", "", n)] += 1
        rtlil = il_f.read_text()
    return outputs, widths, rtlil


# --- RTLIL parsing and register groups ---
SIG_TOKEN = re.compile(r"\{|\}|(\\\S+|\$\S+)(?:\s*\[(\d+)(?::(\d+))?\])?|(\d+'[01xz]+)")


def parse_sigspec(text: str, widths: dict[str, int]) -> list[tuple[str, int] | None]:
    """RTLIL sigspec -> list of (wire, bit) LSB first (None for constants)."""
    chunks = []                       # in written (MSB-first) order
    for m in SIG_TOKEN.finditer(text):
        if m.group(1):
            w = m.group(1)
            if m.group(2) is None:
                bits = list(range(widths.get(w, 1)))
            elif m.group(3) is None:
                bits = [int(m.group(2))]
            else:
                hi, lo = int(m.group(2)), int(m.group(3))
                bits = list(range(lo, hi + 1))
            chunks.append([(w, b) for b in bits])
        elif m.group(4):
            chunks.append([None] * int(m.group(4).split("'")[0]))
    return [b for chunk in reversed(chunks) for b in chunk]


def parse_rtlil(rtlil: str) -> dict[str, dict]:
    """Per module: wire widths, ports, cells, connects, blackbox/keep_hierarchy flags."""
    mods: dict[str, dict] = {}
    mod = cell = None
    blackbox = kept = False
    for line in rtlil.splitlines():
        t = line.split()
        if not t:
            continue
        if mod is None:
            if t[0] == "attribute" and t[1] == "\\blackbox":
                blackbox = True
            elif t[0] == "attribute" and t[1] == "\\keep_hierarchy":
                kept = True
            elif t[0] == "module":
                mod = mods.setdefault(t[1], {"blackbox": blackbox, "kept": kept, "widths": {},
                                             "inputs": set(), "outputs": set(),
                                             "cells": [], "connects": []})
                blackbox = kept = False
            continue
        if line == "end":                       # end of the module (not indented)
            mod = cell = None
        elif t[0] == "wire":
            w = t[-1]
            mod["widths"][w] = int(t[t.index("width") + 1]) if "width" in t else 1
            if "output" in t:
                mod["outputs"].add(w)
            if "input" in t:
                mod["inputs"].add(w)
        elif t[0] == "cell":
            cell = {"type": t[1], "name": t[2], "conn": {}}
            mod["cells"].append(cell)
        elif t[0] == "end":
            cell = None
        elif t[0] == "connect":
            rest = line.strip()[len("connect"):].strip()
            if cell is not None:
                port, _, sig = rest.partition(" ")
                cell["conn"][port] = sig
            else:
                mod["connects"].append(rest)
    return mods


class Nets:
    """The nets of one module: which wire bits are names for the same net."""

    def __init__(self, mod: dict):
        self.widths = mod["widths"]
        self.parent: dict = {}
        for c in mod["connects"]:
            # "lhs rhs": split where the right-hand sigspec starts.
            depth, split = 0, None
            for m in SIG_TOKEN.finditer(c):
                if m.group(0) == "{": depth += 1
                elif m.group(0) == "}": depth -= 1
                if depth == 0 and m.group(0) != "{":
                    split = m.end()
                    break
            lhs = parse_sigspec(c[:split], self.widths)
            rhs = parse_sigspec(c[split:], self.widths)
            for a, b in zip(lhs, rhs):
                if a and b:
                    self.parent[self.find(a)] = self.find(b)
        self.members = defaultdict(list)
        for w, n in self.widths.items():
            for b in range(n):
                self.members[self.find((w, b))].append((w, b))

    def find(self, x):
        self.parent.setdefault(x, x)
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def bitname(self, w: str, b: int) -> str:
        name = w[1:] if w.startswith("\\") else w
        return name if self.widths[w] == 1 else f"{name}[{b}]"

    def names(self, sig: str) -> set[str]:
        """Every name of every net in the sigspec `sig`."""
        bits = [b for b in parse_sigspec(sig, self.widths) if b]
        return {self.bitname(*m) for b in bits for m in self.members[self.find(b)]}


def register_groups(top: dict, gate_names: set[str]) -> list[list[str]]:
    """Names (shared with the netlist) of the bits of each multi-bit register."""
    nets = Nets(top)
    sigs = [c["conn"]["\\Q"] for c in top["cells"]
            if re.search(r"dff", c["type"], re.I) and "\\Q" in c["conn"]]
    groups = []
    for sig in sigs:
        if len([b for b in parse_sigspec(sig, nets.widths) if b]) < 2:
            continue
        names = sorted(nets.names(sig) & gate_names)
        if len(names) >= 2:
            groups.append(names)
    return groups


def kept_module_sections(mods: dict[str, dict], top: str) -> list[str]:
    """[collect] sections proving each kept module as one piece per output port."""
    lines = []
    for c in mods[top]["cells"]:
        sub = mods.get(c["type"])
        if not sub or not sub["kept"]:
            continue
        inst = f"{top[1:]}.{c['name'][1:] if c['name'].startswith(chr(92)) else c['name']}"
        groups = [[f"{w[1:]}[{i}]" for i in range(sub["widths"][w])]
                  for w in sorted(sub["outputs"]) if sub["widths"][w] > 1]
        if groups:
            lines += ["", f"[collect {eqy_pattern(inst)}]"] + group_lines(groups)
    return lines


def box_net_hides(mods: dict[str, dict], top: str, gate_names: set[str]) -> list[str]:
    """RTL-only names of nets on black-box and kept-module pins."""
    nets = Nets(mods[top])
    hide = set()
    for c in mods[top]["cells"]:
        box = mods.get(c["type"])
        if not box or not (box["blackbox"] or box["kept"]):
            continue
        for port, sig in c["conn"].items():
            hide |= nets.names(sig) - gate_names
    return sorted(n for n in hide if not n.startswith("$"))


def netlist_names(netlist: Path) -> set[str]:
    """Every net name declared in the netlist, bit by bit."""
    names = set()
    decl = re.compile(r"^\s*(?:wire|input|output|inout)\s*(?:\[(\d+):(\d+)\])?\s*(\\\S+|[A-Za-z_][\w$]*)\s*;")
    for line in netlist.read_text().splitlines():
        m = decl.match(line)
        if not m:
            continue
        name = m.group(3).lstrip("\\")
        if m.group(1) is None:
            names.add(name)
        else:
            hi, lo = int(m.group(1)), int(m.group(2))
            names.update(f"{name}[{i}]" for i in range(min(hi, lo), max(hi, lo) + 1))
    return names


def group_lines(groups: list[list[str]]) -> list[str]:
    if not groups:
        return ["# (no multi-bit registers)"]
    return [f"group /^(?:{'|'.join(re.escape(n) for n in g)})$/" for g in groups]


def eqy_pattern(name: str) -> str:
    """eqy patterns are shell globs; escape anything that is not plain."""
    if re.match(r"[A-Za-z0-9_.]+(\[\d+\])?\Z", name):
        return name
    return "".join(c if c.isalnum() or c == "_" else "\\" + c for c in name)


def yosys_pattern(name: str) -> str:
    """Yosys select pattern that matches exactly `name` (escapes glob characters)."""
    return "".join(c if c.isalnum() or c == "_" else "\\" + c for c in name)


def bind_lines(outputs: list[str], widths: dict[str, int]) -> list[str]:
    """`solo` + `bind` lines for every output bit."""
    by_port: dict[str, list[str]] = defaultdict(list)
    for bit in outputs:
        by_port[re.sub(r"\[\d+\]$", "", bit)].append(bit)
    lines = []
    for port in sorted(by_port):
        bits = by_port[port]
        if widths[port] > 1 and len(bits) == widths[port] and re.match(r"[A-Za-z0-9_.]+\Z", port):
            pats = [f"{port}[]"]  # eqy: "name[]" = every bit of name
        else:
            pats = [eqy_pattern(b) for b in sorted(bits)]
        lines += [f"{cmd} {pat}" for pat in pats for cmd in ("solo", "bind")]
    return lines


def main() -> None:
    ap = argparse.ArgumentParser(description="Fill in eqy.template for one design/platform.")
    ap.add_argument("--template", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--top", required=True)
    ap.add_argument("--frontend", default="slang", choices=["slang", "verilog"])
    ap.add_argument("--adder", default="ripple",
                    help="SYNTH_ADDER: the gold side maps its adders the same way")
    ap.add_argument("--netlist", required=True)
    ap.add_argument("--rtl", nargs="+", required=True)
    ap.add_argument("--cell-libs", nargs="+", required=True)
    ap.add_argument("--macro-libs", nargs="*", default=[])
    ap.add_argument("--incdirs", nargs="*", default=[])
    ap.add_argument("--defines", nargs="*", default=[])
    ap.add_argument("--params", nargs="*", default=[], help="top-level parameters NAME=VALUE")
    ap.add_argument("--blackbox-cells", nargs="*", default=[],
                    help="library cells the RTL instantiates directly (e.g. the ICG cell);"
                         " kept as black boxes on both sides")
    ap.add_argument("--slang-hierarchy", action="store_true",
                    help="read the RTL as synthesis did with SLANG_HIERARCHY=1")
    ap.add_argument("--yosys", default="yosys")
    a = ap.parse_args()

    # macros stay black boxes on both sides
    macro_lines = [f"read_liberty -lib {m}" for m in a.macro_libs]
    inc = " ".join(f"-I {i}" for i in a.incdirs)
    dfs = " ".join(f"-D {d}" for d in a.defines)
    rtl = " ".join(a.rtl)
    prm = " ".join(f"-G {p}" for p in a.params)
    if a.frontend == "slang":
        hier = "--best-effort-hierarchy" if a.slang_hierarchy else ""
        read = f"read_slang --top {a.top} {hier} {inc} {dfs} {prm} {rtl}"
    else:
        read = f"read_verilog -sv {inc} {dfs} {rtl}" + "".join(
            f"\nchparam -set {p.split('=', 1)[0]} {p.split('=', 1)[1]} {a.top}" for p in a.params)
    # library cells the RTL instantiates (ICG) as black boxes on the gold side
    bb_libs = [f"read_liberty -lib {lib}" for lib in a.cell_libs] if a.blackbox_cells else []
    gold = "\n".join(bb_libs + macro_lines + [" ".join(read.split())])
    # gate side: cells as logic; unmodeled and listed cells as black boxes
    gate = "\n".join(
        [f"read_liberty -ignore_miss_func {lib}" for lib in a.cell_libs] + macro_lines
        + ([f"read_liberty -lib -nooverwrite {lib}" for lib in a.cell_libs] if a.blackbox_cells else [])
        + [f"blackbox ={c}" for c in a.blackbox_cells]   # '=': also match existing black boxes
    )
    outputs, widths, rtlil = analyze_gold(a.yosys, gold, a.top)
    gate_names = netlist_names(Path(a.netlist))
    mods = parse_rtlil(rtlil)
    groups = register_groups(mods["\\" + a.top], gate_names)
    hides = box_net_hides(mods, "\\" + a.top, gate_names)

    text = Path(a.template).read_text()
    for key, val in {
        "@TOP@": a.top,
        "@GOLD_READ@": gold,
        "@GATE_LIBS@": gate,
        "@NETLIST@": a.netlist,
        "@BINDS@": "\n".join(bind_lines(outputs, widths)),
        "@TECHMAP@": "techmap" if a.adder == "ripple"
                     else f"techmap -map +/techmap.v -map +/choices/{a.adder}.v",
        "@GROUPS@": "\n".join(group_lines(groups)),
        "@KEPT_MODULES@": "\n".join(kept_module_sections(mods, "\\" + a.top))
                          or "# (none)",
        "@GOLD_HIDE@": "\n".join(f"rename -hide w:{yosys_pattern(n)}" for n in hides)
                       or "# (none)",
    }.items():
        text = text.replace(key, val)
    Path(a.out).write_text(text)


if __name__ == "__main__":
    main()
