#!/usr/bin/env bash
# Grader regression test, no API calls: a known-good run must pass every
# assertion for eval 1, a known-bad run must fail most of them.
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd); EJ=$E/../skills/barbacana-waf-install/evals/evals.json
: "${BARBACANA_BIN:?set BARBACANA_BIN}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -R "$E/selftest/eval1-good" "$E/selftest/eval1-bad" "$tmp/"
python3 "$E/grade.py" "$EJ" 1 "$tmp/eval1-good"; python3 "$E/grade.py" "$EJ" 1 "$tmp/eval1-bad" || true
g=$(jq -r '.summary|"\(.passed) \(.total)"' "$tmp/eval1-good/grading.json")
b=$(jq -r '.summary.passed' "$tmp/eval1-bad/grading.json")
[ "${g% *}" = "${g#* }" ] || { echo "selftest FAIL: good run scored $g"; exit 1; }
[ "$b" -le 2 ] || { echo "selftest FAIL: bad run passed $b"; exit 1; }
echo "selftest OK (good $g, bad $b passed)"
