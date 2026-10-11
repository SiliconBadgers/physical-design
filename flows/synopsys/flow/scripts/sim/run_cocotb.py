#!/usr/bin/env python3
# File:        run_cocotb.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Builds and runs a cocotb testbench with Synopsys VCS. Used by make sim (RTL) and make gls (routed netlist).

import argparse
import sys
from pathlib import Path

from cocotb_tools.runner import get_results, get_runner


def main() -> int:
    ap = argparse.ArgumentParser(description="Build and run a cocotb testbench with VCS.")
    ap.add_argument("--toplevel", required=True, help="HDL top module")
    ap.add_argument("--test-module", required=True, help="cocotb test module (python file name, no .py)")
    ap.add_argument("--test-dir", required=True, help="directory containing the test module")
    ap.add_argument("--build-dir", required=True, help="VCS build and run directory")
    ap.add_argument("--results", required=True, help="JUnit results.xml to write")
    ap.add_argument("--sources", nargs="+", required=True)
    ap.add_argument("--incdir", action="append", default=[])
    ap.add_argument("--define", action="append", default=[], help="NAME or NAME=VALUE")
    ap.add_argument("--param", action="append", default=[], help="top-level parameter NAME=VALUE")
    ap.add_argument("--waves", default="0", help="1 = write waves.vcd in the build directory")
    ap.add_argument("--vcs-arg", action="append", default=[], help="extra VCS compile option")
    args = ap.parse_args()

    defines = {}
    for d in args.define:
        name, eq, value = d.partition("=")
        defines[name] = value if eq else 1     # NAME= keeps an empty value
    params = dict(p.split("=", 1) for p in args.param)

    # timescale for files without one; the cocotb VCS runner ignores its timescale argument
    vcs_args = ["-timescale=1ns/1ps", *args.vcs_arg]
    if args.waves == "1":
        vcs_args.append("+vcs+dumpvars+waves.vcd")   # dump every signal to a VCD file

    build_dir = Path(args.build_dir).resolve()
    # the simulator's Python finds the test module through sys.path
    sys.path.insert(0, str(Path(args.test_dir).resolve()))

    runner = get_runner("vcs")
    runner.build(
        sources=[Path(s).resolve() for s in args.sources],
        hdl_toplevel=args.toplevel,
        includes=[Path(i).resolve() for i in args.incdir],
        defines=defines,
        parameters=params,
        build_dir=build_dir,
        build_args=vcs_args,
        always=True,
    )
    results = runner.test(
        hdl_toplevel=args.toplevel,
        test_module=args.test_module,
        build_dir=build_dir,
        test_dir=build_dir,
        results_xml=str(Path(args.results).resolve()),
    )
    num_tests, num_failed = get_results(Path(results))
    print(f"SB: {num_tests - num_failed}/{num_tests} cocotb tests passed -> {args.results}")
    return 1 if num_failed else 0


if __name__ == "__main__":
    sys.exit(main())
