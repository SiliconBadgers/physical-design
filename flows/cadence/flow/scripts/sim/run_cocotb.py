#!/usr/bin/env python3
# File:        run_cocotb.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Builds and runs a cocotb testbench with Xcelium (xrun) through the cocotb runner. Used by make sim.

import argparse
import sys
from pathlib import Path

from cocotb_tools.runner import get_results, get_runner


def main() -> int:
    ap = argparse.ArgumentParser(description="Build and run a cocotb testbench with Xcelium.")
    ap.add_argument("--toplevel", required=True, help="HDL top module")
    ap.add_argument("--test-module", required=True, help="cocotb test module (python file name, no .py)")
    ap.add_argument("--test-dir", required=True, help="directory containing the test module")
    ap.add_argument("--build-dir", required=True)
    ap.add_argument("--results", required=True, help="JUnit results.xml to write")
    ap.add_argument("--sources", nargs="+", required=True)
    ap.add_argument("--incdir", action="append", default=[])
    ap.add_argument("--define", action="append", default=[], help="NAME or NAME=VALUE")
    ap.add_argument("--param", action="append", default=[], help="top-level parameter NAME=VALUE")
    ap.add_argument("--waves", default="0", help="1 = write an SHM waveform database (open it with SimVision)")
    ap.add_argument("--sim-arg", action="append", default=[], help="extra xrun argument for the build step")
    args = ap.parse_args()

    defines = {}
    for d in args.define:
        name, eq, value = d.partition("=")
        defines[name] = value if eq else 1
    params = dict(p.split("=", 1) for p in args.param)

    runner = get_runner("xcelium")
    # Xcelium takes waves only in the test step, not in the build step
    runner.build(
        sources=[Path(s).resolve() for s in args.sources],
        hdl_toplevel=args.toplevel,
        includes=[Path(i).resolve() for i in args.incdir],
        defines=defines,
        parameters=params,
        build_dir=args.build_dir,
        timescale=("1ns", "1ps"),
        build_args=args.sim_arg,
        always=True,
    )
    # the test module is imported from --test-dir; xrun runs in the build folder, so its logs and waves land there
    sys.path.insert(0, str(Path(args.test_dir).resolve()))
    results = runner.test(
        hdl_toplevel=args.toplevel,
        test_module=args.test_module,
        test_dir=str(Path(args.build_dir).resolve()),
        build_dir=args.build_dir,
        results_xml=str(Path(args.results).resolve()),
        waves=args.waves == "1",
    )
    num_tests, num_failed = get_results(Path(results))
    print(f"SB: {num_tests - num_failed}/{num_tests} cocotb tests passed -> {args.results}")
    return 1 if num_failed else 0


if __name__ == "__main__":
    sys.exit(main())
