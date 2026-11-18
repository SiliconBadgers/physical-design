#!/usr/bin/env python3
# File:        test_signoff_check.py
# Author:      Isaac Hagedorn
# Date:        2026-10-29
# Description: Tests of the drc, lvs and sign-off checks (make test-gates). Each case runs the real make target in a scratch build
#              folder on made-up results, with a small stand-in for Pegasus, and checks the exit status, the message, the done
#              stamp and that the report is kept. Needs make, bash and Python 3, no EDA tools.
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

TRACK = Path(__file__).resolve().parents[3]

# stand-in: Pegasus copies SB_FIXTURE to <top>.drc.sum (-drc) or <top>.lvs.rpt (-lvs)
PEGASUS = '''#!/bin/bash
case " $* " in *" -drc "*) out=gcd.drc.sum ;; *) out=gcd.lvs.rpt ;; esac
if [ -n "${SB_FIXTURE:-}" ]; then cp "$SB_FIXTURE" "$out"; fi
'''



def drc_sum(results):
    return f"Pegasus DRC summary\nTotal DRC Results Generated: {results} ({results})\n"


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
        args = [f"PEGASUS={self.file('pegasus', PEGASUS, 0o755)}", f"DRC_DECK={self.file('deck.pvl', '')}"]
        return self.make("drc.done", *args, fixture=fixture, old=["final.gds"])

    def lvs(self, fixture):
        (self.build / "final.gds").write_text("")
        (self.build / "final_lvs.v").write_text("")
        args = [f"PEGASUS={self.file('pegasus', PEGASUS, 0o755)}", f"LVS_DECK={self.file('deck.rul', '')}",
                f"CELL_CDL={self.file('cells.cdl', '')}"]
        return self.make("lvs.rpt", *args, fixture=fixture, old=["final.gds"])

    def signoff(self, setup, hold, metrics):
        """make signoff.done on a finish.json with these values."""
        (self.build / "finish.json").write_text(json.dumps(metrics))
        return self.make("signoff.done", f"SETUP_CORNERS={setup}", f"HOLD_CORNERS={hold}", old=["finish.json"])

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
        self.passes(self.drc(drc_sum(0)), "drc.done", "drc: 0 violations")
        self.assertEqual((self.build / "drc_count.txt").read_text(), "0\n")

    def test_drc_violations(self):
        self.fails(self.drc(drc_sum(3)), "drc.done", "drc FAILED -- 3 violations: read")
        self.assertEqual((self.build / "drc_count.txt").read_text(), "3\n")
        self.assertTrue((self.build / "drc" / "gcd.drc.sum").exists())

    def test_drc_no_results(self):
        self.fails(self.drc(None), "drc.done", "drc FAILED -- the violation count in")

    def test_drc_garbage_summary(self):
        self.fails(self.drc("Segmentation fault\n"), "drc.done", "is not a number ('unknown')")

    # --- lvs ---
    def test_lvs_match(self):
        self.passes(self.lvs("Run Result : MATCH\n"), "lvs.rpt", "LVS: layout matches netlist")

    def test_lvs_mismatch(self):
        self.fails(self.lvs("Run Result : MISMATCH\n"), "lvs.rpt", "LVS FAILED")
        self.assertTrue((self.build / "lvs" / "gcd.lvs.rpt").exists())

    def test_lvs_no_report_after_a_match(self):
        (self.build / "lvs").mkdir()
        (self.build / "lvs" / "gcd.lvs.rpt").write_text("Run Result : MATCH\n")   # an earlier run's
        self.fails(self.lvs(None), "lvs.rpt", "LVS FAILED")

    # --- sign-off slack (Tempus, per corner in finish.json) ---
    def test_signoff_positive(self):
        m = {"finish__timing__setup__ws__corner:tt": 0.375, "finish__timing__hold__ws__corner:tt": 0.452}
        self.passes(self.signoff("tt", "tt", m), "signoff.done", "finish: sign-off slack >= 0 (setup tt 0.375, hold tt 0.452)")

    def test_signoff_negative_setup(self):
        m = {"finish__timing__setup__ws__corner:tt": -1.25, "finish__timing__hold__ws__corner:tt": 0.452}
        self.fails(self.signoff("tt", "tt", m), "signoff.done",
                   "finish FAILED -- sign-off setup slack at tt is -1.25 (must be >= 0): read")
        self.assertTrue((self.build / "finish.json").exists())

    def test_signoff_negative_hold(self):
        m = {"finish__timing__setup__ws__corner:tt": 0.375, "finish__timing__hold__ws__corner:tt": -0.5}
        self.fails(self.signoff("tt", "tt", m), "signoff.done", "finish FAILED -- sign-off hold slack at tt is -0.5 (must be >= 0)")

    def test_signoff_missing(self):
        m = {"finish__timing__setup__ws": 0.375, "finish__timing__hold__ws": 0.452}   # no per-corner values
        self.fails(self.signoff("tt", "tt", m), "signoff.done", "finish FAILED -- sign-off setup slack at tt is missing")

    def test_signoff_nan(self):
        m = {"finish__timing__setup__ws__corner:tt": 0.375, "finish__timing__hold__ws__corner:tt": float("nan")}
        self.fails(self.signoff("tt", "tt", m), "signoff.done", "finish FAILED -- sign-off hold slack at tt is nan (not a finite number)")

    def test_signoff_negative_at_one_of_two(self):
        m = {"finish__timing__setup__ws__corner:ss": -4.053, "finish__timing__setup__ws__corner:tt": 0.375,
             "finish__timing__hold__ws__corner:ff": 0.287, "finish__timing__hold__ws__corner:tt": 0.452}
        self.fails(self.signoff("ss tt", "ff tt", m), "signoff.done", "sign-off setup slack at ss is -4.053")

    def test_signoff_report_only_corner(self):
        # ss is a setup corner only and ff a hold corner only: hold at ss and setup at ff are not checked
        m = {"finish__timing__setup__ws__corner:ss": 0.07, "finish__timing__hold__ws__corner:ss": -0.5,
             "finish__timing__setup__ws__corner:ff": -1.0, "finish__timing__hold__ws__corner:ff": 0.287}
        self.passes(self.signoff("ss", "ff", m), "signoff.done", "finish: sign-off slack >= 0 (setup ss 0.07, hold ff 0.287)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
