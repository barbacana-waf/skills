#!/usr/bin/env bash
# Run a skill's evals headlessly, with and without the skill, and grade them.
#
#   evals/run.sh [--skill NAME] [--eval ID] [--iteration N] [--model M]
#                [--budget USD] [--only with|without] [--dry-run]
#
# Needs: claude (Claude Code CLI), jq, python3, and a barbacana binary
# (BARBACANA_BIN, or on PATH) for the validate_config assertions.
# Results: evals/workspace/iteration-N/<skill>/eval-<id>/{with_skill,without_skill}/
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKILL="" EVAL="" ITER=1 MODEL="" BUDGET=1.50 ONLY="" DRY=0
while [ $# -gt 0 ]; do
  case $1 in
    --skill) SKILL=$2; shift 2;;
    --eval) EVAL=$2; shift 2;;
    --iteration) ITER=$2; shift 2;;
    --model) MODEL=$2; shift 2;;
    --budget) BUDGET=$2; shift 2;;
    --only) ONLY=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    *) echo "unknown flag $1" >&2; exit 2;;
  esac
done

BARBACANA_BIN=${BARBACANA_BIN:-$(command -v barbacana || true)}
[ -x "${BARBACANA_BIN:-}" ] || { echo "set BARBACANA_BIN to a barbacana binary (release archive or 'make build')" >&2; exit 1; }
export BARBACANA_BIN
for t in jq python3; do command -v $t >/dev/null || { echo "missing $t" >&2; exit 1; }; done
[ $DRY = 1 ] || command -v claude >/dev/null || { echo "missing claude CLI" >&2; exit 1; }

# Identical for both arms, so the only variable is the skill. Keeps the run
# to files and read-only commands: no containers, clusters or services.
SUFFIX='

Environment note: this is a sandbox with no Docker, no Kubernetes cluster and no access to my servers. Do not try to start services. Write the files you would create into the current directory, run barbacana --validate if useful, and describe in your answer the exact commands you would run next.'

BIN_DIR=$(mktemp -d); ln -s "$BARBACANA_BIN" "$BIN_DIR/barbacana"
trap 'rm -rf "$BIN_DIR"' EXIT

skills=${SKILL:-$(cd "$ROOT/skills" && ls)}
for skill in $skills; do
  ej="$ROOT/skills/$skill/evals/evals.json"
  [ -f "$ej" ] || continue
  ids=$(jq -r '.evals[].id' "$ej")
  [ -z "$EVAL" ] || ids=$EVAL
  [ -n "$ids" ] || continue
  for id in $ids; do
    prompt=$(jq -r --argjson id "$id" '.evals[]|select(.id==$id)|.prompt' "$ej")
    for arm in with_skill without_skill; do
      [ -z "$ONLY" ] || [ "$arm" = "${ONLY}_skill" ] || continue
      run="$ROOT/evals/workspace/iteration-$ITER/$skill/eval-$id/$arm"
      rm -rf "$run"; mkdir -p "$run/workdir"
      fixtures="$ROOT/skills/$skill/evals/files/$id"
      [ ! -d "$fixtures" ] || cp -R "$fixtures/." "$run/workdir/"
      if [ $arm = with_skill ]; then
        mkdir -p "$run/workdir/.claude/skills"
        # never ship evals (assertions) to the agent
        rsync -a --exclude evals "$ROOT/skills/$skill" "$run/workdir/.claude/skills/"
      fi
      echo "== $skill eval $id $arm"
      if [ $DRY = 1 ]; then echo "   workdir: $run/workdir"; echo "   prompt: $prompt"; continue; fi
      start=$(date +%s)
      ( cd "$run/workdir" && PATH="$BIN_DIR:$PATH" claude -p "$prompt$SUFFIX" \
          --output-format json --no-session-persistence \
          --setting-sources project --permission-mode dontAsk \
          --allowedTools Read Write Edit Glob Grep "Bash(barbacana:*)" "Bash(gh release list:*)" "Bash(ls:*)" "Bash(cat:*)" \
          --max-budget-usd "$BUDGET" ${MODEL:+--model "$MODEL"} \
          > "$run/transcript.json" 2> "$run/stderr.log" ) || echo "   claude exited non-zero (see stderr.log)"
      jq -r '.result // ""' "$run/transcript.json" > "$run/response.md" 2>/dev/null || : > "$run/response.md"
      jq -n --argjson s "$start" --argjson e "$(date +%s)" --slurpfile t "$run/transcript.json" \
        '{duration_s: ($e-$s), cost_usd: ($t[0].total_cost_usd // null), turns: ($t[0].num_turns // null)}' > "$run/timing.json" 2>/dev/null || true
      PATH="$BIN_DIR:$PATH" python3 "$ROOT/evals/grade.py" "$ej" "$id" "$run"
    done
  done
done
[ $DRY = 1 ] || python3 "$ROOT/evals/summarize.py" "$ROOT/evals/workspace/iteration-$ITER"
