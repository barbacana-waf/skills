#!/usr/bin/env bash
# Grader regression test, no API calls: a known-good run must pass every
# assertion for eval 1, a known-bad run must fail most of them.
set -euo pipefail
E=$(cd "$(dirname "$0")" && pwd); EJ=$E/skills/barbacana-waf-install/evals.json
: "${BARBACANA_BIN:?set BARBACANA_BIN}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -R "$E/selftest/eval1-good" "$E/selftest/eval1-bad" "$tmp/"
python3 "$E/grade.py" "$EJ" 1 "$tmp/eval1-good"; python3 "$E/grade.py" "$EJ" 1 "$tmp/eval1-bad" || true
g=$(jq -r '.summary|"\(.passed) \(.total)"' "$tmp/eval1-good/grading.json")
b=$(jq -r '.summary.passed' "$tmp/eval1-bad/grading.json")
[ "${g% *}" = "${g#* }" ] || { echo "selftest FAIL: good run scored $g"; exit 1; }
[ "$b" -le 2 ] || { echo "selftest FAIL: bad run passed $b"; exit 1; }
echo "selftest OK (good $g, bad $b passed)"

# tool_* assertions against a synthetic transcript (no API, no barbacana needed)
python3 - "$E" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
import grade
calls = [("Skill", '{"skill": "x-skill"}'), ("Bash", '{"command": "graphify query q"}'), ("Grep", '{"pattern": "a"}')]
def t(c): return grade.check(c, "/nonexistent", "", calls)[0]
assert t({"type": "tool_called", "tool": "Skill", "regex": "x-skill"})
assert t({"type": "tool_called", "tool": "Skill|Read", "regex": "x-skill"})
assert not t({"type": "tool_called", "tool": "Write"})
assert t({"type": "tool_not_called", "tool": "Write"})
assert t({"type": "tool_order", "before": {"tool": "Bash", "regex": "graphify query"}, "after": {"tool": "Grep"}})
assert not t({"type": "tool_order", "before": {"tool": "Grep"}, "after": {"tool": "Bash"}})
assert not t({"type": "tool_order", "before": {"tool": "Write"}, "after": {"tool": "Grep"}})
print("selftest tool assertions OK")
PY
