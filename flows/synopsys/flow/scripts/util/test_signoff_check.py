#!/usr/bin/env python3
# File:        test_signoff_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-29
# Description: Tests of the drc and sign-off checks (make test-gates). Each case runs the real make target in a scratch build
#              folder on made-up results, with a small stand-in for KLayout, and checks the exit status, the message, the
#              done stamp and that the report is kept. Needs make, bash and Python 3, no EDA tools.
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

TRACK = Path(__file__).resolve().parents[3]

ITEM = "  <item>\n   <category>'m1.2'</category>\n   <values>\n    <value>edge-pair: (0,0;1,0)|(0,0.1;1,0.1)</value>\n   </values>\n  </item>\n"
# stand-in: KLayout copies SB_FIXTURE to its report_file
KLAYOUT = '''#!/bin/bash
for a in "$@"; do case $a in report_file=*) out=${a#report_file=} ;; esac; done
if [ -n "${SB_FIXTURE:-}" ]; then cp "$SB_FIXTURE" "$out"; fi
'''


def lyrdb(markers):
    return f'<?xml version="1.0" encoding="utf-8"?>\n<report-database>\n <items>\n{ITEM * markers} </items>\n</report-database>\n'



class Gates(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="test-gates-")
        self.dir = Path(self.tmp.name)
        self.build = self.dir / "build"
        self.build.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def file(self, name, text, mode=0o644):
        path = self.dir / name
        path.write_text(text)
        path.chmod(mode)
        return path

    def make(self, target, *args, fixture=None, old=()):
        """Run make <build>/<target>; old: files make takes as made (-o). Returns (exit status, output)."""
        env = {k: v for k, v in os.environ.items() if k not in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL")}
        env["SB_FIXTURE"] = str(self.file("fixture", fixture)) if fixture is not None else ""
        cmd = ["make", "--no-print-directory", "-C", str(TRACK), str(self.build / target),
               f"BUILD={self.build}", "DESIGN=gcd", *args]
        for f in old:
            cmd += ["-o", str(self.build / f)]
        r = subprocess.run(cmd, env=env, capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    def drc(self, fixture):
        (self.build / "final.gds").write_text("")
        return self.make("drc.done", f"KLAYOUT={self.file('klayout', KLAYOUT, 0o755)}", fixture=fixture, old=["final.gds"])

    def signoff(self, setup, hold, corners):
        """make signoff.done on signoff_<corner>.json files with the given values."""
        (self.build / "finish.json").write_text("{}\n")
        for c, values in corners.items():
            (self.build / f"signoff_{c}.json").write_text(json.dumps(values))
            (self.build / f"signoff_{c}.done").write_text("")
        return self.make("signoff.done", f"SETUP_CORNERS={setup}", f"HOLD_CORNERS={hold}",
                         old=[f"signoff_{c}.done" for c in corners])

    def passes(self, result, stamp, message):
        rc, out = result
        self.assertEqual(rc, 0, out)
        self.assertIn(message, out)
        self.assertTrue((self.build / stamp).exists(), out)

    def fails(self, result, stamp, message):
        rc, out = result
        self.assertNotEqual(rc, 0, out)
        self.assertIn(message, out)
        self.assertFalse((self.build / stamp).exists(), out)

    # --- drc ---
    def test_drc_clean(self):
        self.passes(self.drc(lyrdb(0)), "drc.done", "drc: 0 violations")
        self.assertEqual((self.build / "drc_count.txt").read_text(), "0\n")

    def test_drc_violation(self):
        self.fails(self.drc(lyrdb(1)), "drc.done", "drc FAILED -- 1 violation: read")
        self.assertEqual((self.build / "drc_count.txt").read_text(), "1\n")
        self.assertTrue((self.build / "drc.lyrdb").exists())

    def test_drc_no_report(self):
        self.fails(self.drc(None), "drc.done", "drc FAILED -- no DRC report")

    def test_drc_garbage_report(self):
        self.fails(self.drc("Segmentation fault\n"), "drc.done", "drc FAILED -- cannot read the DRC report")

    # --- sign-off slack ---
    def test_signoff_positive(self):
        self.passes(self.signoff("tt", "tt", {"tt": {"setup_ws_ns": 0.161, "hold_ws_ns": 0.54}}), "signoff.done",
                    "finish: sign-off slack >= 0 (setup tt 0.161, hold tt 0.54)")

    def test_signoff_negative_setup(self):
        self.fails(self.signoff("tt", "tt", {"tt": {"setup_ws_ns": -1.25, "hold_ws_ns": 0.54}}), "signoff.done",
                   "finish FAILED -- sign-off setup slack at tt is -1.25 (must be >= 0): read")
        self.assertEqual(json.loads((self.build / "finish.json").read_text())["finish__timing__setup__ws"], -1.25)

    def test_signoff_negative_hold(self):
        self.fails(self.signoff("tt", "tt", {"tt": {"setup_ws_ns": 0.161, "hold_ws_ns": -0.5}}), "signoff.done",
                   "finish FAILED -- sign-off hold slack at tt is -0.5 (must be >= 0)")

    def test_signoff_missing(self):
        self.fails(self.signoff("tt", "tt", {"tt": {"hold_ws_ns": 0.54}}), "signoff.done",
                   "finish FAILED -- sign-off setup slack at tt is missing")

    def test_signoff_null(self):
        self.fails(self.signoff("tt", "tt", {"tt": {"setup_ws_ns": 0.161, "hold_ws_ns": None}}), "signoff.done",
                   "finish FAILED -- sign-off hold slack at tt is missing")

    def test_signoff_nan(self):
        self.fails(self.signoff("tt", "tt", {"tt": {"setup_ws_ns": float("nan"), "hold_ws_ns": 0.54}}), "signoff.done",
                   "finish FAILED -- sign-off setup slack at tt is nan (not a finite number)")

    def test_signoff_negative_at_one_of_two(self):
        corners = {"ss": {"setup_ws_ns": -0.47, "hold_ws_ns": 0.19}, "tt": {"setup_ws_ns": 0.16, "hold_ws_ns": 0.12},
                   "ff": {"setup_ws_ns": 0.49, "hold_ws_ns": 0.07}}
        self.fails(self.signoff("ss tt", "ff tt", corners), "signoff.done", "sign-off setup slack at ss is -0.47")

    def test_signoff_report_only_corner(self):
        # ss is a setup corner only and ff a hold corner only: ss hold and ff setup are reported, not checked
        corners = {"ss": {"setup_ws_ns": 0.07, "hold_ws_ns": -0.5}, "ff": {"setup_ws_ns": -1.0, "hold_ws_ns": 0.36}}
        self.passes(self.signoff("ss", "ff", corners), "signoff.done", "finish: sign-off slack >= 0 (setup ss 0.07, hold ff 0.36)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
