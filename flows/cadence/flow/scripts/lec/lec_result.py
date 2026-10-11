#!/usr/bin/env python3
# File:        lec_result.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: One-line PASS/FAIL summary of a Conformal run from the compare-point counts it printed (pass: compare points, none non-equivalent, aborted or unknown).
#              Usage: lec_result.py <step> <log>.
import re
import sys
from pathlib import Path

KEYS = ("compare", "diff", "abort", "unknown")


def counts(text: str) -> dict[str, int] | None:
    """The last "No of <key> points = N" of each key, or None if Conformal did not print them."""
    found = {k: re.findall(rf"No of {k} points\s*=\s*(\d+)", text) for k in KEYS}
    if not all(found.values()):
        return None
    return {k: int(v[-1]) for k, v in found.items()}


def summary(text: str) -> tuple[bool, str]:
    c = counts(text)
    if c is None:
        return False, "FAIL (no compare-point counts: Conformal did not finish)"
    ok = c["compare"] > 0 and c["diff"] == c["abort"] == c["unknown"] == 0
    return ok, (f"{'PASS' if ok else 'FAIL'} ({c['compare']} compare points, {c['diff']} non-equivalent, "
                f"{c['abort']} aborted, {c['unknown']} unknown)")


def main() -> int:
    step, log = sys.argv[1], Path(sys.argv[2])
    ok, msg = summary(log.read_text(errors="replace") if log.exists() else "")
    print(f"LEC {step}: {msg}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
