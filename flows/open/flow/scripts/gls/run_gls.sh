#!/usr/bin/env bash
# File:        run_gls.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Gate-level simulation: runs the RTL cocotb testbench on the netlist plus cell models. Usage: run_gls.sh <build> <netlist> <top> <tb-module> <tb-dir> <waves> "<defines>" <verilog files...>
set -euo pipefail
build=$1 netlist=$2 top=$3 tb_module=$4 tb_dir=$5 waves=$6 defines=$7
shift 7
here=$(cd "$(dirname "$0")" && pwd)

sim=${GLS_SIM:-icarus}      # icarus (4-state) or verilator (2-state)
def_args=() sim_args=()
# Verilator does not model #1 cell delays: define UNIT_DELAY empty
for d in $defines; do
    [ "$sim" = verilator ] && [ "${d%%=*}" = UNIT_DELAY ] && d="UNIT_DELAY="
    def_args+=(--define "$d")
done
if [ "$sim" = verilator ]; then
    # cell models are not lint-clean
    sim_args=(--sim-arg=-Wno-fatal --sim-arg=-Wno-lint --sim-arg=-Wno-style)
fi

python3 "$here/../sim/run_cocotb.py" \
  --toplevel "$top" --test-module "$tb_module" --test-dir "$tb_dir" \
  --build-dir "$build/sim_gls" --results "$build/gls_results.xml" --waves "$waves" \
  --sim "$sim" "${sim_args[@]}" "${def_args[@]}" \
  --sources "$netlist" "$@"
