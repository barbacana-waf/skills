#!/usr/bin/env bash
# Run a skill's evals headlessly, with and without the skill, and grade them.
#
#   evals/run-evals.sh [--agent claude|opencode] [--skill NAME] [--eval ID]
#                      [--iteration N] [--model M] [--budget USD]
#                      [--only with|without] [--dry-run]
#
# Agents:
#   claude    (default) the Claude Code CLI. --model is a Claude model name.
#   opencode  the OpenCode CLI. --model is provider/model, as `opencode models`
#             prints it; omit it to use OpenCode's configured default. Found via
#             OPENCODE_BIN, then PATH, then the OpenCode desktop app bundle.
#             --budget does not apply. Bash, web access and every skill but the
#             one under test are locked down through OPENCODE_CONFIG_CONTENT,
#             matching what the claude arm is allowed.
#
# Needs: the chosen agent's CLI, jq, python3, and a barbacana binary
# (BARBACANA_BIN, or on PATH) for the validate_config assertions.
# Results: $EVALS_WORKSPACE (default evals/workspace; a temp dir outside the repo for opencode)/iteration-N/<skill>/eval-<id>/{with_skill,without_skill}/
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKILL="" EVAL="" ITER=1 MODEL="" BUDGET=1.50 ONLY="" DRY=0 AGENT=claude
while [ $# -gt 0 ]; do
  case $1 in
    --skill) SKILL=$2; shift 2;;
    --eval) EVAL=$2; shift 2;;
    --iteration) ITER=$2; shift 2;;
    --model) MODEL=$2; shift 2;;
    --budget) BUDGET=$2; shift 2;;
    --only) ONLY=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    *) echo "unknown flag $1" >&2; exit 2;;
  esac
done

# Where runs happen. OpenCode treats the enclosing git repo as its project and
# can read all of it, so for that agent runs go outside the repo by default;
# otherwise the baseline arm finds skills/ and evals.json by walking upward.
WORKSPACE=${EVALS_WORKSPACE:-$ROOT/evals/workspace}
[ $AGENT = opencode ] && [ -z "${EVALS_WORKSPACE:-}" ] && WORKSPACE=${TMPDIR:-/tmp}/barbacana-evals-workspace
mkdir -p "$WORKSPACE"
BARBACANA_BIN=${BARBACANA_BIN:-$(command -v barbacana || true)}
[ -x "${BARBACANA_BIN:-}" ] || { echo "set BARBACANA_BIN to a barbacana binary (release archive or 'make build')" >&2; exit 1; }
export BARBACANA_BIN
for t in jq python3; do command -v $t >/dev/null || { echo "missing $t" >&2; exit 1; }; done
case $AGENT in
  claude)
    [ $DRY = 1 ] || command -v claude >/dev/null || { echo "missing claude CLI" >&2; exit 1; };;
  opencode)
    OPENCODE_BIN=${OPENCODE_BIN:-$(command -v opencode || true)}
    [ -x "${OPENCODE_BIN:-}" ] || OPENCODE_BIN=/Applications/OpenCode.app/Contents/Resources/opencode-cli
    [ $DRY = 1 ] || [ -x "$OPENCODE_BIN" ] || { echo "missing opencode CLI (set OPENCODE_BIN)" >&2; exit 1; };;
  *) echo "unknown agent $AGENT (claude|opencode)" >&2; exit 2;;
esac

# Identical for both arms, so the only variable is the skill. Keeps the run
# to files and read-only commands: no containers, clusters or services.
SUFFIX='

Environment note: this is a sandbox with no Docker, no Kubernetes cluster and no access to my servers. Do not try to start services. Write the files you would create into the current directory, run barbacana --validate if useful, and describe in your answer the exact commands you would run next.'

BIN_DIR=$(mktemp -d); ln -s "$BARBACANA_BIN" "$BIN_DIR/barbacana"
trap 'rm -rf "$BIN_DIR"' EXIT

# OpenCode permissions for one arm: file access only inside the run directory
# (otherwise the baseline finds this repo's skills/ by globbing upward), no
# ls/cat in the shell for the same reason (read and glob tools cover them),
# no web (the code-execution tool is switched off too: with it the baseline
# fetched the docs and this repo's published skills over HTTP), and either only
# barbacana-* skills or no skills at all.
oc_config() {
  jq -cn --arg skills "$1" '{tools: {execute: false}, permission: {
    external_directory: "deny",
    bash: {"*": "deny", "barbacana *": "allow", "gh release list*": "allow"},
    skill: ({"*": "deny"} + (if $skills == "allow" then {"barbacana-*": "allow"} else {} end)),
    webfetch: "deny", websearch: "deny"}}'
}

# OpenCode's event stream -> Claude-style stream-json (assistant tool_use events
# plus one final result event), so grade.py and the jq below need no changes.
oc_to_claude() {
  jq -cs '
    def cap: (.[0:1] | ascii_upcase) + .[1:];
    def tname: {"shell": "Bash"}[.] // cap;
    ([.[] | select(.type == "tool_use")
          | {type: "assistant", message: {content: [{type: "tool_use", name: (.part.tool | tname), input: (.part.state.input // {})}]}}]) as $calls
    | ([to_entries[] | select(.value.type == "tool_use") | .key] | last // -1) as $last
    | ([to_entries[] | select(.key > $last and .value.type == "text") | .value.part.text] | join("")) as $final
    | [.[] | select(.type == "step_finish")] as $steps
    | $calls[], {type: "result", result: $final,
                 total_cost_usd: ([$steps[].part.cost // 0] | add // 0), num_turns: ($steps | length)}'
}

skills=${SKILL:-$(cd "$ROOT/skills" && ls)}
for skill in $skills; do
  ej="$ROOT/evals/skills/$skill/evals.json"
  [ -f "$ej" ] || continue
  ids=$(jq -r '.evals[].id' "$ej")
  [ -z "$EVAL" ] || ids=$EVAL
  [ -n "$ids" ] || continue
  for id in $ids; do
    prompt=$(jq -r --argjson id "$id" '.evals[]|select(.id==$id)|.prompt' "$ej")
    for arm in with_skill without_skill; do
      [ -z "$ONLY" ] || [ "$arm" = "${ONLY}_skill" ] || continue
      run="$WORKSPACE/iteration-$ITER/$skill/eval-$id/$arm"
      rm -rf "$run"; mkdir -p "$run/workdir"
      fixtures="$ROOT/evals/skills/$skill/files/$id"
      [ ! -d "$fixtures" ] || cp -R "$fixtures/." "$run/workdir/"
      if [ $arm = with_skill ]; then
        mkdir -p "$run/workdir/.claude/skills"
        # the installed layout: evals live outside skills/, so nothing to exclude
        cp -R "$ROOT/skills/$skill" "$run/workdir/.claude/skills/"
      fi
      echo "== $skill eval $id $arm"
      if [ $DRY = 1 ]; then echo "   agent: $AGENT${MODEL:+ ($MODEL)}"; echo "   workdir: $run/workdir"; echo "   prompt: $prompt"; continue; fi
      start=$(date +%s)
      if [ $AGENT = claude ]; then
        ( cd "$run/workdir" && PATH="$BIN_DIR:$PATH" claude -p "$prompt$SUFFIX" \
            --output-format stream-json --verbose --no-session-persistence \
            --setting-sources project --permission-mode dontAsk \
            --allowedTools Read Write Edit Glob Grep "Bash(barbacana:*)" "Bash(gh release list:*)" "Bash(ls:*)" "Bash(cat:*)" \
            --max-budget-usd "$BUDGET" ${MODEL:+--model "$MODEL"} \
            > "$run/transcript.jsonl" 2> "$run/stderr.log" ) || echo "   claude exited non-zero (see stderr.log)"
      else
        arm_skills=allow; [ $arm = with_skill ] || arm_skills=deny
        ( cd "$run/workdir" && PATH="$BIN_DIR:$PATH" OPENCODE_CONFIG_CONTENT="$(oc_config $arm_skills)" \
            "$OPENCODE_BIN" run --standalone --auto --format json ${MODEL:+-m "$MODEL"} "$prompt$SUFFIX" \
            > "$run/transcript.opencode.jsonl" 2> "$run/stderr.log" ) || echo "   opencode exited non-zero (see stderr.log)"
        oc_to_claude < "$run/transcript.opencode.jsonl" > "$run/transcript.jsonl" 2>/dev/null || : > "$run/transcript.jsonl"
      fi
      jq -rs '[.[]|select(.type=="result")]|last|.result // ""' "$run/transcript.jsonl" > "$run/response.md" 2>/dev/null || : > "$run/response.md"
      jq -n --arg a "$AGENT" --argjson s "$start" --argjson e "$(date +%s)" --slurpfile t "$run/transcript.jsonl" \
        '([$t[]|select(.type=="result")]|last) as $r | {agent: $a, duration_s: ($e-$s), cost_usd: ($r.total_cost_usd // null), turns: ($r.num_turns // null)}' > "$run/timing.json" 2>/dev/null || true
      PATH="$BIN_DIR:$PATH" python3 "$ROOT/evals/grade.py" "$ej" "$id" "$run"
    done
  done
done
[ $DRY = 1 ] || python3 "$ROOT/evals/summarize.py" "$WORKSPACE/iteration-$ITER"
