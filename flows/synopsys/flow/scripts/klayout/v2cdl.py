#!/usr/bin/env python3
# File:        v2cdl.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Turns a gate-level Verilog netlist into one flat CDL subcircuit for KLayout LVS. Cell pin order comes from the CDL files given with --cdl.

import argparse
import re
import sys

POWER = {"VPWR", "VPB", "VDD"}   # power pins tied to VDD when the netlist leaves them out
GROUND = {"VGND", "VNB", "VSS"}  # ground pins tied to VSS when the netlist leaves them out
TOKEN = re.compile(r"\\\S+|[A-Za-z_][\w$]*|\d*'[sS]?[bBoOdDhH][0-9a-fA-FxXzZ_?]+|\d+|\S")
SKIP = {"parameter", "localparam", "defparam", "specify", "timeunit", "timeprecision", "`timescale"}


def tokenize(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)  # block comments
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)  # attributes
    text = re.sub(r"//[^\n]*", " ", text)                # line comments
    return TOKEN.findall(text)


def name(tok):
    """Net or instance name; escaped Verilog names keep their brackets escaped."""
    if tok.startswith("\\"):
        return tok[1:].replace("[", "\\[").replace("]", "\\]")
    return tok


def statements(toks, i):
    """Split a module body into statements; returns (list, index after endmodule)."""
    out, cur, depth = [], [], 0
    while toks[i] != "endmodule" or depth:
        t = toks[i]
        depth += t in "({[" and len(t) == 1
        depth -= t in ")}]" and len(t) == 1
        if t == ";" and depth == 0:
            out.append(cur)
            cur = []
        else:
            cur.append(t)
        i += 1
    return out, i + 1


def split_top(toks, sep=","):
    """Split a token list at separators outside brackets."""
    parts, cur, depth = [], [], 0
    for t in toks:
        if t in ("(", "{", "["):
            depth += 1
        elif t in (")", "}", "]"):
            depth -= 1
        if t == sep and depth == 0:
            parts.append(cur)
            cur = []
        else:
            cur.append(t)
    parts.append(cur)
    return [p for p in parts if p]


def const_bits(tok):
    """Bits of a sized constant, MSB first, as VDD/VSS."""
    size, val = tok.split("'")
    base = val.lstrip("sS")[0].lower()
    digits = val.lstrip("sS")[1:].replace("_", "")
    num = int(digits, {"b": 2, "o": 8, "d": 10, "h": 16}[base])
    width = int(size) if size else max(1, num.bit_length())
    return ["VDD" if (num >> b) & 1 else "VSS" for b in reversed(range(width))]


class Module:
    def __init__(self, mname):
        self.name = mname
        self.ports = []      # port names in header order
        self.ranges = {}     # bus name -> (msb, lsb)
        self.supply = {}     # supply0/1 net -> VSS/VDD
        self.assigns = []    # (lhs tokens, rhs tokens)
        self.insts = []      # (master, instance, {pin: tokens} or [tokens])

    def bits(self, toks):
        """Expand an expression into net bits, MSB first."""
        if not toks:
            return []
        if toks[0] == "{":
            inner = toks[1:-1]
            if len(inner) > 1 and inner[0].isdigit() and inner[1] == "{":   # replication {N{...}}
                return int(inner[0]) * self.bits(inner[1:])
            return [b for part in split_top(inner) for b in self.bits(part)]
        if "'" in toks[0]:
            return const_bits(toks[0])
        net = name(toks[0])
        if len(toks) >= 4 and toks[1] == "[":
            if toks[3] == ":":
                msb, lsb = int(toks[2]), int(toks[4])
                step = -1 if msb >= lsb else 1
                return [f"{net}[{b}]" for b in range(msb, lsb + step, step)]
            return [f"{net}[{toks[2]}]"]
        if net in self.ranges:
            msb, lsb = self.ranges[net]
            step = -1 if msb >= lsb else 1
            return [f"{net}[{b}]" for b in range(msb, lsb + step, step)]
        return [net]

    def port_bits(self, port):
        return self.bits([port])


def declare(mod, st):
    """Record a declaration: direction or net type, optional range, names."""
    kind, rest = st[0], st[1:]
    rest = [t for t in rest if t not in ("wire", "reg", "logic", "signed", "unsigned", "tri")]
    rng = None
    if rest and rest[0] == "[":
        rng = (int(rest[1]), int(rest[3]))
        rest = rest[5:]
    for part in split_top(rest):
        n = name(part[0])
        if rng:
            mod.ranges[n] = rng
        if kind in ("supply0", "supply1"):
            mod.supply[n] = "VSS" if kind == "supply0" else "VDD"
        if kind in ("input", "output", "inout") and n not in mod.ports:
            mod.ports.append(n)


def parse(text):
    toks = tokenize(text)
    modules, i = {}, 0
    while i < len(toks):
        if toks[i] != "module":
            i += 1
            continue
        mod = Module(name(toks[i + 1]))
        i += 2
        if toks[i] == "#":                       # parameter list
            depth, i = 0, i + 1
            while True:
                depth += toks[i] == "("
                depth -= toks[i] == ")"
                i += 1
                if depth == 0:
                    break
        body, i = statements(toks, i)
        header = body.pop(0) if body else []
        hdr = header[1:-1] if header and header[0] == "(" else []
        for part in split_top(hdr):              # plain or ANSI port list
            if part[0] in ("input", "output", "inout"):
                declare(mod, part)
            else:
                mod.ports.append(name(part[-1]))
        for st in body:
            if not st or st[0] in SKIP:
                continue
            if st[0] in ("input", "output", "inout", "wire", "reg", "logic", "tri", "supply0", "supply1", "wand", "wor"):
                declare(mod, st)
            elif st[0] == "assign":
                for part in split_top(st[1:]):
                    eq = part.index("=")
                    mod.assigns.append((part[:eq], part[eq + 1:]))
            else:
                parse_instances(mod, st)
        modules[mod.name] = mod
    return modules


def parse_instances(mod, st):
    """One instance statement: master [#(...)] inst (conns) [, inst (conns)]."""
    master, rest = st[0], st[1:]
    if rest and rest[0] == "#":
        depth, k = 0, 1
        while True:
            depth += rest[k] == "("
            depth -= rest[k] == ")"
            k += 1
            if depth == 0:
                break
        rest = rest[k:]
    for part in split_top(rest):
        inst, conns = name(part[0]), part[2:-1]
        items = split_top(conns)
        if items and items[0][0] == ".":
            pins = {it[1]: it[3:-1] for it in items}
        else:
            pins = items
        mod.insts.append((master, inst, pins))


def read_cdl(paths):
    """Subcircuit name -> pin list, from CDL/SPICE files."""
    subckts = {}
    for path in paths:
        lines, cur = [], ""
        with open(path) as fh:
            for line in fh:
                line = line.rstrip("\n")
                if line.startswith("+"):
                    cur += " " + line[1:]
                else:
                    lines.append(cur)
                    cur = line
            lines.append(cur)
        for line in lines:
            f = line.split()
            if f and f[0].upper() == ".SUBCKT":
                subckts[f[1]] = [p for p in f[2:] if "=" not in p]
    return subckts


class Nets:
    """Union-find over global net names; supplies, then top ports, win as names."""
    def __init__(self, ports):
        self.parent, self.ports = {}, ports

    def rank(self, n):
        return 2 if n in ("VDD", "VSS") else 1 if n in self.ports else 0

    def find(self, n):
        self.parent.setdefault(n, n)
        while self.parent[n] != n:
            self.parent[n] = self.parent[self.parent[n]]
            n = self.parent[n]
        return n

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra == rb:
            return
        if self.rank(rb) > self.rank(ra):
            ra, rb = rb, ra
        self.parent[rb] = ra


def flatten(modules, cells, top):
    """Instances of leaf cells with global net names."""
    out, nc = [], [0]
    top_mod = modules[top]
    top_ports = [b for p in top_mod.ports for b in top_mod.port_bits(p)]
    nets = Nets(set(top_ports))

    def walk(mod, prefix, portmap):
        def g(bit):
            if bit in ("VDD", "VSS"):
                return bit
            if bit in portmap:
                return portmap[bit]
            base = bit.split("[")[0]
            if base in mod.supply:
                return mod.supply[base]
            return prefix + bit
        for lhs, rhs in mod.assigns:
            for a, b in zip(mod.bits(lhs), mod.bits(rhs)):
                nets.union(g(a), g(b))
        for master, inst, pins in mod.insts:
            path = prefix + inst
            if master in modules and master not in cells:
                sub = modules[master]
                if isinstance(pins, dict):
                    sub_bits = {p: sub.port_bits(p) for p in pins}
                    conn = {p: mod.bits(e) for p, e in pins.items()}
                else:
                    sub_bits = {p: sub.port_bits(p) for p in sub.ports}
                    conn = dict(zip(sub.ports, (mod.bits(e) for e in pins)))
                pm = {}
                for p, bits in conn.items():
                    for sb, b in zip(sub_bits[p], bits):
                        pm[sb] = g(b)
                walk(sub, path + "/", pm)
                continue
            cell_pins = cells.get(master) or cells.get(master.upper()) or cells.get(master.lower())
            if cell_pins is None:
                print(f"v2cdl: warning: no subcircuit for {master} ({path}), skipped", file=sys.stderr)
                continue
            if not isinstance(pins, dict):
                pins = dict(zip(cell_pins, pins))
            bitmap = {}
            for p, e in pins.items():
                bits = mod.bits(e)
                if len(bits) == 1:
                    bitmap[p] = g(bits[0])
                else:                         # bus pin of a macro: pin[msb] ... pin[lsb]
                    idx = sorted((int(cp.split("[")[1][:-1]) for cp in cell_pins
                                  if cp.startswith(p + "[")), reverse=True)
                    for k, b in zip(idx, bits):
                        bitmap[f"{p}[{k}]"] = g(b)
            row = []
            for cp in cell_pins:
                if cp in bitmap:
                    row.append(bitmap[cp])
                elif cp in POWER:
                    row.append("VDD")
                elif cp in GROUND:
                    row.append("VSS")
                else:
                    nc[0] += 1
                    row.append(f"nc_{nc[0]}")
            out.append((path, master, row))

    walk(top_mod, "", {b: b for b in top_ports})
    pins = top_ports + [s for s in ("VDD", "VSS") if s not in top_ports]
    insts = [(path, master, [nets.find(n) for n in row]) for path, master, row in out]
    return pins, insts


def wrap(words):
    lines, cur = [], words[0]
    for w in words[1:]:
        if len(cur) + len(w) + 1 > 78:
            lines.append(cur)
            cur = "+ " + w
        else:
            cur += " " + w
    lines.append(cur)
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Gate-level Verilog to flat CDL for KLayout LVS.")
    ap.add_argument("netlist", help="Verilog netlist (with power pins and physical cells)")
    ap.add_argument("--top", required=True, help="top module")
    ap.add_argument("--cdl", action="append", default=[], help="CDL file with cell subcircuits (repeat)")
    ap.add_argument("-o", "--output", help="output file (default: stdout)")
    args = ap.parse_args()

    with open(args.netlist) as fh:
        modules = parse(fh.read())
    if args.top not in modules:
        sys.exit(f"v2cdl: module {args.top} not found in {args.netlist}")
    pins, insts = flatten(modules, read_cdl(args.cdl), args.top)

    text = [f"* {args.top}: CDL for LVS, made by v2cdl.py from {args.netlist}",
            wrap([".SUBCKT", args.top] + pins)]
    for path, master, row in insts:
        text.append(wrap(["X" + path] + row + [master]))
    text.append(f".ENDS {args.top}\n")
    out = open(args.output, "w") if args.output else sys.stdout
    out.write("\n".join(text))
    if args.output:
        out.close()
    print(f"v2cdl: {args.top}: {len(insts)} instances, {len(pins)} pins", file=sys.stderr)


if __name__ == "__main__":
    main()
