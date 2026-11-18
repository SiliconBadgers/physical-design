#!/usr/bin/env python3
# File:        sb_lint.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Team lint rule SB-SENS (part of make lint): no hand-written sensitivity list on a combinational always block. Usage: sb_lint.py <rtl files...>

import re
import sys
from pathlib import Path

ALWAYS = re.compile(r"\balways\s*@\s*(\*|\(([^)]*)\))")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//(?!\s*sb_lint:).*", "", text)


def check(path: Path) -> list[str]:
    out = []
    for n, line in enumerate(strip_comments(path.read_text()).splitlines(), 1):
        m = ALWAYS.search(line)
        if not m or re.search(r"\b(posedge|negedge)\b", m.group(0)):
            continue
        if m.group(1) == "*" or (m.group(2) or "").strip() == "*":
            continue                       # @* / @(*): complete by definition
        if re.search(r"sb_lint:\s*allow\s+SB-SENS\s+\S", line):
            continue                       # opt-out: // sb_lint: allow SB-SENS <reason>
        out.append(f"%Error-SB-SENS: {path}:{n}: combinational `{m.group(0)}` -- use always_comb or always @* "
                   "(see docs/reading_synth_logs.md#lint)")
    return out


def main() -> int:
    errors = [e for f in sys.argv[1:] for e in check(Path(f))]
    print("\n".join(errors) if errors else "sb_lint: no violations")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
