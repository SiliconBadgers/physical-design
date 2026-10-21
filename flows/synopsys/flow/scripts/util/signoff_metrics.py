#!/usr/bin/env python3
# File:        signoff_metrics.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Adds the PrimeTime sign-off slack to finish.json: setup from the setup corners, hold from the hold corners. Usage: signoff_metrics.py <finish.json> --setup <signoff_<corner>.json ...> --hold <signoff_<corner>.json ...>
import argparse
import json
from pathlib import Path


def worst(files, key):
    """Lowest value of key over the corner files; None if a corner has no value."""
    values = [json.loads(Path(f).read_text()).get(key) for f in files]
    return None if not values or None in values else min(values)


def main():
    ap = argparse.ArgumentParser(description="Add PrimeTime sign-off slack to finish.json.")
    ap.add_argument("metrics", help="finish.json written by the finish stage")
    ap.add_argument("--setup", nargs="+", required=True, help="signoff_<corner>.json of the setup corners")
    ap.add_argument("--hold", nargs="+", required=True, help="signoff_<corner>.json of the hold corners")
    a = ap.parse_args()

    path = Path(a.metrics)
    m = json.loads(path.read_text())
    m["finish__timing__setup__ws"] = worst(a.setup, "setup_ws_ns")
    m["finish__timing__setup__tns"] = worst(a.setup, "setup_tns_ns")
    m["finish__timing__hold__ws"] = worst(a.hold, "hold_ws_ns")
    m["finish__timing__hold__tns"] = worst(a.hold, "hold_tns_ns")
    path.write_text(json.dumps(m, indent=2) + "\n")
    print(f"SB: sign-off setup WS {m['finish__timing__setup__ws']} ns, TNS {m['finish__timing__setup__tns']} ns, "
          f"hold WS {m['finish__timing__hold__ws']} ns -> {path}")


if __name__ == "__main__":
    main()
