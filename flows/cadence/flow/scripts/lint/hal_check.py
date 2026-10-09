#!/usr/bin/env python3
# File:        hal_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Lint gate for make lint: reads the Xcelium HAL log and fails on any error, or on any warning no waiver file covers. Usage: hal_check.py <hal.log> [<waiver file>...]

import fnmatch
import re
import sys
from pathlib import Path


def waivers(files: list[str]) -> list[tuple[str, str]]:
    """(message code, file pattern) per line; '#' starts a comment."""
    out = []
    for f in files:
        for line in Path(f).read_text().splitlines():
            fields = line.split("#", 1)[0].split()
            if fields:
                out.append((fields[0], fields[1] if len(fields) > 1 else "*"))
    return out


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit("usage: hal_check.py <hal.log> [<waiver file>...]")
    log = Path(sys.argv[1]).read_text(errors="replace")
    rules = waivers(sys.argv[2:])
    rc = re.search(r"SB: xrun exit status (\d+)", log)
    if not rc:
        print("LINT_STATUS: hal.log is incomplete: FAIL")
        return 1
    if rc.group(1) in ("126", "127"):
        print("LINT_STATUS: xrun did not run (not found or not executable): FAIL")
        return 1

    lines = [ln.strip() for ln in log.splitlines()]
    errors = [ln for ln in lines if re.search(r"\*[EF],", ln)]
    unwaived, waived = [], 0
    for ln in (x for x in lines if "*W," in x):
        # *W,<CODE> (<file>,<line>|<col>): <message>
        m = re.search(r"\*W,(\w+)(?:\s*\(([^,)]+))?", ln)
        code, where = (m.group(1), m.group(2) or "") if m else ("", "")
        if any(code == c and fnmatch.fnmatch(where, p) for c, p in rules):
            waived += 1
        else:
            unwaived.append(ln)

    for ln in (errors + unwaived)[:20]:
        print(ln)
    ok = not errors and not unwaived
    print(f"LINT_STATUS: HAL {len(errors)} error(s), {len(unwaived)} warning(s), {waived} waived: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
