#!/usr/bin/env python3
# File:        signoff_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-29
# Description: The pass/fail checks of make drc and of sign-off in make finish; exits 1 with one line per failed check.
#              drc <count file> [--lyrdb <report>]: the DRC violation count must be a whole number, 0. With --lyrdb the count is the
#              number of markers in that KLayout report, written to <count file> first. A missing or unreadable report or count fails.
#              slack --setup <corners> --hold <corners> --json <file> --setup-key <key> --hold-key <key> [--report <file>]: the worst
#              setup slack at each setup corner and the worst hold slack at each hold corner must be a finite number >= 0.
#              {corner} in the file names and keys stands for the corner. Same file in every track.
import argparse
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def lyrdb_markers(path):
    """Number of markers in a KLayout report database (lyrdb)."""
    root = ET.parse(path).getroot()
    items = root.find("items")
    if root.tag != "report-database" or items is None:
        raise ValueError("not a KLayout report database")
    return len(items.findall("item"))


def check_drc(a):
    """Failure lines for the DRC count."""
    count = Path(a.count)
    report = a.lyrdb or a.report or count
    if a.lyrdb:
        if not Path(a.lyrdb).is_file():
            return [f"drc FAILED -- no DRC report {a.lyrdb}"]
        try:
            n = lyrdb_markers(a.lyrdb)
        except (ET.ParseError, ValueError, OSError) as e:
            return [f"drc FAILED -- cannot read the DRC report {a.lyrdb}: {e}"]
        count.write_text(f"{n}\n")
    try:
        text = count.read_text().strip()
    except OSError:
        return [f"drc FAILED -- no violation count ({count} is missing)"]
    if not text:
        return [f"drc FAILED -- no violation count ({count} is empty): read {report}"]
    if not re.fullmatch(r"[0-9]+", text):
        return [f"drc FAILED -- the violation count in {count} is not a number ('{text[:40]}'): read {report}"]
    n = int(text)
    if n:
        return [f"drc FAILED -- {n} violation{'s' if n > 1 else ''}: read {report}"]
    print(f"drc: 0 violations ({report})")
    return []


def slack(path, key):
    """The slack at key in a JSON file, or None and why it is not a number."""
    try:
        value = json.loads(Path(path).read_text())[key]
    except OSError:
        return None, f"missing ({path} cannot be read)"
    except ValueError as e:
        return None, f"missing ({path} is not JSON: {e})"
    except (KeyError, TypeError):
        return None, f"missing (no {key} in {path})"
    if value is None:
        return None, f"missing ({key} is null in {path})"
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None, f"not a number ({key} is {json.dumps(value)} in {path})"
    if not math.isfinite(value):
        return None, f"{value} (not a finite number)"
    return value, None


def check_slack(a):
    """Failure lines for the sign-off slack at every setup and hold corner."""
    failed, passed = [], []
    for check, corners, key in (("setup", a.setup, a.setup_key), ("hold", a.hold, a.hold_key)):
        corners = " ".join(corners).split()
        if not corners:
            failed.append(f"finish FAILED -- no sign-off {check} corner")
        for c in corners:
            value, why = slack(a.json.replace("{corner}", c), key.replace("{corner}", c))
            if why is None and value < 0:
                why = f"{value} (must be >= 0)"
            read = f": read {a.report.replace('{corner}', c)}" if a.report else ""
            if why is None:
                passed.append(f"{check} {c} {value}")
            else:
                failed.append(f"finish FAILED -- sign-off {check} slack at {c} is {why}{read}")
    if not failed:
        print(f"finish: sign-off slack >= 0 ({', '.join(passed)})")
    return failed


def main():
    ap = argparse.ArgumentParser(description="DRC and sign-off timing checks.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("drc", help="the DRC violation count must be 0")
    d.add_argument("count", help="file with the violation count (written first with --lyrdb)")
    d.add_argument("--lyrdb", help="KLayout report database: count its markers")
    d.add_argument("--report", help="the DRC results, named in the message")
    s = sub.add_parser("slack", help="sign-off slack must be >= 0 at every setup and hold corner")
    s.add_argument("--setup", nargs="+", required=True, help="setup corners")
    s.add_argument("--hold", nargs="+", required=True, help="hold corners")
    s.add_argument("--json", required=True, help="metrics file ({corner}: the corner)")
    s.add_argument("--setup-key", required=True, help="worst setup slack key ({corner}: the corner)")
    s.add_argument("--hold-key", required=True, help="worst hold slack key ({corner}: the corner)")
    s.add_argument("--report", help="timing report, named in the message ({corner}: the corner)")
    a = ap.parse_args()

    failed = check_drc(a) if a.cmd == "drc" else check_slack(a)
    for line in failed:
        print(line)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
