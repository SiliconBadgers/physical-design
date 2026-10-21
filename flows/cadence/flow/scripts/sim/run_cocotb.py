#!/usr/bin/env python3
# File:        run_cocotb.py
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Builds and runs a cocotb testbench with Xcelium (xrun) through the cocotb runner. Used by make sim (RTL) and make gls (routed netlist).

import argparse
import os
import signal
import sys
from pathlib import Path

from cocotb_tools.runner import get_results, get_runner


class SimTimeout(Exception):
    """The simulation ran longer than --timeout seconds."""


def processes() -> dict:
    """pid -> parent pid, for every process we can see."""
    ppid = {}
    for d in os.listdir("/proc"):
        if d.isdigit():
            try:
                with open(f"/proc/{d}/stat") as f:
                    ppid[int(d)] = int(f.read().rsplit(")", 1)[1].split()[1])
            except (OSError, ValueError, IndexError):
                continue
    return ppid


def kill_descendants() -> None:
    """SIGKILL every process started (directly or not) by this one: the simulator and its helpers."""
    children = {}
    for pid, parent in processes().items():
        children.setdefault(parent, []).append(pid)
    todo, found = [os.getpid()], []
    while todo:
        for c in children.get(todo.pop(), []):
            found.append(c)
            todo.append(c)
    for pid in found:
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass


def stop_dcservmgr(build_dir: Path) -> None:
    """Xcelium leaves a dcservmgr.exe daemon running after the simulation; stop the one this run started."""
    for pid in processes():
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() != "dcservmgr.exe":
                    continue
            with open(f"/proc/{pid}/environ", "rb") as f:
                env = dict(v.split(b"=", 1) for v in f.read().split(b"\0") if b"=" in v)
            if Path(env.get(b"PWD", b"").decode()).resolve().is_relative_to(build_dir):
                os.kill(pid, signal.SIGTERM)
        except (OSError, ValueError):
            continue


def on_alarm(signum, frame):
    kill_descendants()
    raise SimTimeout()


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
    ap.add_argument("--timeout", type=int, default=0, help="wall-clock limit of the simulation in seconds (0 = none)")
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
    # a simulation that never advances (e.g. a combinational loop) is killed after --timeout seconds
    if args.timeout > 0:
        signal.signal(signal.SIGALRM, on_alarm)
        signal.alarm(args.timeout)
    try:
        results = runner.test(
            hdl_toplevel=args.toplevel,
            test_module=args.test_module,
            test_dir=str(Path(args.build_dir).resolve()),
            build_dir=args.build_dir,
            results_xml=str(Path(args.results).resolve()),
            waves=args.waves == "1",
        )
    except SimTimeout:
        print(f"SB-ERROR: the simulation did not finish within SIM_TIMEOUT={args.timeout} s and was killed. "
              "A simulation that never advances is often a combinational loop: read the loop reports (synth_check_timing.rpt, the check_timing section of sta.rpt).")
        return 1
    finally:
        signal.alarm(0)
        stop_dcservmgr(Path(args.build_dir).resolve())
    num_tests, num_failed = get_results(Path(results))
    print(f"SB: {num_tests - num_failed}/{num_tests} cocotb tests passed -> {args.results}")
    return 1 if num_failed else 0


if __name__ == "__main__":
    sys.exit(main())
