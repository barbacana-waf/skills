#!/usr/bin/env bash
# Checks each skills/*/SKILL.md: frontmatter name matches the folder,
# description present, body under 500 lines.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
for f in skills/*/SKILL.md; do
  dir=$(basename "$(dirname "$f")")
  name=$(awk -F': *' '/^name:/{print $2; exit}' "$f")
  [ "$name" = "$dir" ] || { echo "$f: name '$name' != folder '$dir'"; fail=1; }
  grep -q '^description:' "$f" || { echo "$f: missing description"; fail=1; }
  [ "$(wc -l < "$f")" -lt 500 ] || { echo "$f: 500 lines or more"; fail=1; }
done
exit $fail
