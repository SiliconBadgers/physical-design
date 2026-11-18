#!/usr/bin/env bash
# File:        run_lint.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: RTL lint with VC SpyGlass (vc_static_shell) when it is installed, else with vcs +lint=all. Inputs are environment variables set by make; run it from the build folder.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

# LINT_TOOL: auto (VC SpyGlass if found), vc or vcs
tool=${LINT_TOOL:-auto}
if [ "$tool" = auto ]; then
    if command -v vc_static_shell >/dev/null 2>&1; then tool=vc; else tool=vcs; fi
fi

case $tool in
vc)
    echo "== lint: VC SpyGlass, goal lint_rtl (flow/lint/vc_lint.tcl)"
    rm -f lint_vc.rpt
    vc_static_shell -f "$here/vc_lint.tcl" < /dev/null
    [ -s lint_vc.rpt ] || { echo "VC SpyGlass wrote no lint_vc.rpt"; exit 1; }
    echo "SB: lint (VC SpyGlass) done -> lint_vc.rpt"
    ;;
vcs)
    echo "== lint: vcs +lint=all"
    args=()
    for d in ${RTL_INCDIRS:-}; do args+=("+incdir+$d"); done
    for d in ${RTL_DEFINES:-}; do args+=("+define+$d"); done
    mkdir -p lint
    # +lint=all: report every lint message; the simv it builds is not used
    vcs -full64 -sverilog +lint=all -timescale=1ns/1ps -top "$TOP" ${args[@]+"${args[@]}"} $RTL_FILES \
        -Mdir=lint/csrc -o lint/simv -l lint/vcs.log
    n=$(grep -c '^Lint-\[' lint/vcs.log || true)
    echo "SB: lint (vcs +lint=all): $n lint message(s) -> lint/vcs.log"
    ;;
*)
    echo "LINT_TOOL=$tool: use auto, vc or vcs" >&2
    exit 2
    ;;
esac
