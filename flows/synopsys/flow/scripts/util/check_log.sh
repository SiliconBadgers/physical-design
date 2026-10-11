#!/usr/bin/env bash
# File:        check_log.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: Usage: check_log.sh <log> [<regex>]. Fails when the log has an error line (default '^Error:', the Synopsys format) that is not waived below, even if the tool exited 0. Prints the first five error lines and the log path.
set -uo pipefail
log=$1
pattern=${2:-'^Error:'}

# Waivers: message IDs whose error lines are harmless in a passing run, one per line, each with the reason.
# An error line is waived when it contains "(<ID>)". Keep this list short; none is needed so far.
waivers=(
)

errors=$(grep -E -- "$pattern" "$log" || true)
for id in ${waivers[@]+"${waivers[@]}"}; do
    errors=$(grep -v -F -- "($id)" <<< "$errors" || true)
done
[ -z "$errors" ] && exit 0
echo "$(grep -c . <<< "$errors") error line(s) in $log; the first ones:"
head -5 <<< "$errors"
exit 1
