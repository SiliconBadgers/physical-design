#!/usr/bin/env bash
# File:        log_check.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Usage: log_check.sh <stage> <log>... Fails if a Cadence tool log has an error line, even when the tool exited 0 and its
#              script printed "SB: <name> done": Innovus/Tempus/Voltus "**ERROR:" (Voltus library generation "** ERROR:"),
#              Quantus "ERROR (<ID>) :", Xcelium "*E,<CODE>" or "*F,<CODE>". Errors whose message ID is in log_waivers.txt (next to this
#              script) are ignored. Prints the first error lines and the log path.
set -uo pipefail
stage=$1
shift
waivers=$(dirname "$0")/log_waivers.txt
# waived message IDs: first word of each non-comment line
ids=$(sed -e 's/#.*//' "$waivers" 2>/dev/null | awk 'NF {print $1}')

errors=""
for log in "$@"; do
    [ -e "$log" ] || { errors+="$log: missing"$'\n'; continue; }
    while IFS= read -r line; do
        # message ID: (IMPXXX-123) or (EXTXXX-123), or the Xcelium code after *E, / *F,
        id=$(grep -oE '\([A-Z][A-Z0-9_]*-[0-9]+\)|\*[EF],[A-Z0-9_]+' <<< "$line" | head -1 | tr -d '()' | sed 's/^\*[EF],//')
        if [ -n "$id" ] && grep -qxF "$id" <<< "$ids"; then continue; fi
        errors+="$log: $line"$'\n'
    done < <(grep -E '^\*\* ?ERROR:|^[[:space:]]*ERROR \([A-Z][A-Z0-9_]*-[0-9]+\)|\*[EF],[A-Z0-9_]+' "$log")
done

if [ -n "$errors" ]; then
    printf '%s' "$errors" | head -5 | cut -c1-300
    echo "$stage FAILED -- error lines in $* (waivers: $waivers)"
    exit 1
fi
exit 0
