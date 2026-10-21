#!/usr/bin/env python3
# File:        liberty_pin_cap.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Prints the input capacitance of one pin of one Liberty cell, in library units. Usage: liberty_pin_cap.py <file.lib[.gz]> <cell> <pin>

import gzip
import re
import sys
from pathlib import Path


def read(path: Path) -> str:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt") as f:
        return f.read()


def group_body(text: str, start: int) -> str:
    """Text between the '{' at or after start and its matching '}'."""
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    raise ValueError("unbalanced braces")


def pin_cap(lib: Path, cell: str, pin: str) -> float:
    text = read(lib)
    m = re.search(r'\bcell\s*\(\s*"?' + re.escape(cell) + r'"?\s*\)', text)
    if not m:
        raise SystemExit(f"liberty_pin_cap: no cell {cell} in {lib}")
    body = group_body(text, m.end())
    m = re.search(r'\bpin\s*\(\s*"?' + re.escape(pin) + r'"?\s*\)', body)
    if not m:
        raise SystemExit(f"liberty_pin_cap: no pin {pin} on {cell} in {lib}")
    pin_body = group_body(body, m.end())
    # drop nested groups (timing etc.), keep the pin's own attributes
    top = re.sub(r"\{[^{}]*\}", "", pin_body)
    while "{" in top:
        top = re.sub(r"\{[^{}]*\}", "", top)
    m = re.search(r"\bcapacitance\s*:\s*([0-9.eE+-]+)", top)
    if not m:
        raise SystemExit(f"liberty_pin_cap: {cell}/{pin} has no capacitance in {lib}")
    return float(m.group(1))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: liberty_pin_cap.py <file.lib[.gz]> <cell> <pin>")
    print(pin_cap(Path(sys.argv[1]), sys.argv[2], sys.argv[3]))
