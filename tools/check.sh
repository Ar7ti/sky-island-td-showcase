#!/bin/sh
# Static gates: selene (0 errors, warnings must not exceed the baseline) + rojo build of both places.
# Usage: tools/check.sh            (from the repo root)
set -u
cd "$(dirname "$0")/.."
BASELINE_WARNINGS=0
SELENE="${SELENE:-$HOME/.rokit/bin/selene}"
OUT="${TMPDIR:-/tmp}/td-check.$$"
mkdir -p "$OUT"
status=0

summary=$("$SELENE" --display-style quiet src 2>&1 | tail -5)
errors=$(echo "$summary" | sed -n 's/^\([0-9]*\) errors$/\1/p')
warnings=$(echo "$summary" | sed -n 's/^\([0-9]*\) warnings$/\1/p')
# Parse errors are reported on their own line and count as errors (a file selene can't parse isn't linted at all).
parse=$(echo "$summary" | sed -n 's/^\([0-9]*\) parse errors$/\1/p')
errors=${errors:-0}; warnings=${warnings:-0}; parse=${parse:-0}
errors=$((errors + parse))
echo "selene: $errors errors, $warnings warnings (baseline $BASELINE_WARNINGS)"
if [ "$errors" -ne 0 ]; then "$SELENE" --display-style quiet src | grep "error\[" ; status=1; fi
if [ "$warnings" -gt "$BASELINE_WARNINGS" ]; then echo "selene: warnings grew above the baseline"; status=1; fi

for project in default.project.json lobby.project.json; do
	if rojo build "$project" -o "$OUT/$project.rbxl" >/dev/null 2>"$OUT/err.txt"; then
		echo "rojo build $project: ok"
	else
		echo "rojo build $project: FAILED"; cat "$OUT/err.txt"; status=1
	fi
done
rm -rf "$OUT"
[ $status -eq 0 ] && echo "check: PASS" || echo "check: FAIL"
exit $status
