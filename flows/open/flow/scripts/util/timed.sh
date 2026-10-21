#!/usr/bin/env bash
# File:        timed.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Usage: timed.sh <runtimes-file> <stage> <command...>. Runs the command and records "<stage> <wall-seconds>" in the runtimes file.
set -uo pipefail
times=$1 stage=$2; shift 2
start=$(date +%s.%N)
"$@"
rc=$?
end=$(date +%s.%N)
mkdir -p "$(dirname "$times")"
# keep only the latest run of each stage
{ grep -v "^$stage " "$times" 2>/dev/null || true; awk -v s="$stage" -v a="$start" -v b="$end" 'BEGIN{printf "%s %.2f\n", s, b-a}'; } > "$times.tmp"
mv "$times.tmp" "$times"
exit $rc
