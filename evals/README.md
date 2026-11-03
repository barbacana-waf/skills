# Reproducing the skill evals

Each skill keeps its eval definitions next to it:

```
evals/skills/<skill>/
├── evals.json     # prompts + machine-checkable assertions
└── files/<id>/    # fixture project copied into the agent's working dir (optional)

They sit here, not under `skills/<skill>/`, because the `skills` CLI copies a skill
folder whole into every install and has no ignore mechanism.
```

This folder holds the harness that runs them.

## What a run does

For every eval, twice (**with_skill** and **without_skill**, the baseline):

1. Creates a fresh working dir, copies `files/<id>/` into it.
2. With the skill: copies the skill in as `.claude/skills/<skill>/`, exactly what an install contains, so the agent never sees the assertions.
3. Runs the agent headless with the eval prompt (`claude -p` by default, or OpenCode with `--agent opencode`). Both arms get the same sandbox note (no Docker, cluster or services; write files, describe commands), the same read/write tools, and only `barbacana` and `gh release list` as shell commands. `--setting-sources project` keeps your personal skills out of the Claude run; for OpenCode, a permission config denies every skill except the one under test (and all of them in the baseline arm).
4. Grades the files and the final answer with `grade.py` and prints a with/without table.

## Run it

```bash
# a barbacana binary for the validate_config assertions (release archive, or `make build` in barbacana-waf/barbacana)
export BARBACANA_BIN=/path/to/barbacana

evals/run-evals.sh --dry-run                          # show what would run, no API calls
evals/run-evals.sh --skill barbacana-waf-install          # all evals, both arms
evals/run-evals.sh --skill barbacana-waf-install --eval 4 --only with --iteration 2 --model <model-id>

# the same evals through OpenCode (model as `opencode models` lists it)
evals/run-evals.sh --agent opencode --model opencode-go/<model> --skill barbacana-waf-install
```

Flags: `--agent claude|opencode` (default `claude`); `--budget USD` caps each Claude run (default 1.50; not used by OpenCode). OpenCode is found via `OPENCODE_BIN`, then `PATH`, then the desktop app's bundled `opencode-cli`. For OpenCode runs the raw event stream is kept as `transcript.opencode.jsonl` and converted into the same Claude-style `transcript.jsonl`, so the `tool_called` assertions work for both. Results land in `evals/workspace/iteration-N/<skill>/eval-<id>/<arm>/`: `workdir/` (what the agent wrote), `response.md`, `transcript.jsonl` (stream-json, one event per line), `timing.json`, `grading.json` (`text` / `passed` / `evidence` per assertion, the shape `skill-creator`'s viewer expects). Use a new `--iteration` number after each skill change and compare tables.

Real runs call the API and cost money: expect on the order of a dollar per run.

## Check the grader without the API

```bash
BARBACANA_BIN=/path/to/barbacana evals/selftest.sh
```

Grades a known-good and a known-bad run for eval 1 and fails if the good one misses an assertion or the bad one passes more than two. Run it after editing `grade.py` or any eval's assertions.

## Assertion types

| `type` | Passes when |
|---|---|
| `file_exists` | at least one file matches `glob` |
| `file_contains` | `regex` matches in any file matching `glob` |
| `file_not_contains` | files match `glob` and none contains `regex` (no files = fail, so empty runs do not score) |
| `validate_config` | every matching file with `version: v1beta1` (or the deprecated `v1alpha1`) passes `barbacana --validate`, and there is at least one |
| `tool_called` / `tool_not_called` | the transcript has (no) call to tool `tool` (regex, full match, e.g. `Skill|Read`) whose input matches optional `regex` |
| `tool_order` | `before` `{tool, regex?}` happens, and earlier than `after` (or `after` never happens). Use it for rules like "query the graph before grepping" |
| `output_contains` / `output_not_contains` | `regex` does / does not match the final answer |

## Adding an eval

Add an entry to the skill's `evals.json` with a realistic prompt and 4-10 assertions. Prefer asserting on files and on facts the answer must contain; avoid asserting exact wording. Put any project the prompt refers to under `files/<id>/`. Then write the passing case into `selftest/` if the new assertion types need regression coverage.

## Known limits

- Assertions check outcomes, not the path taken. A pass does not prove the agent followed the skill's steps; read a few `transcript.jsonl` files, or add the `tool_*` assertions below.
- The Kubernetes Service check is a regex over the manifest, not a parsed object model.
- Trigger quality is tested separately, see below.
- One sample per eval is noisy. Repeat important comparisons with several iterations.

## Cheap-model sweeps

```bash
evals/sweep.sh --models haiku,sonnet --repeats 3 --skill barbacana-waf-install
```

One iteration per (model, repeat), mapped in `evals/workspace/sweep-<base>.tsv`. Compare pass rates, not single runs. Failing on every model points at the skill; failing only on the weakest points at ambiguity worth clarifying. For non-Anthropic models, set `ANTHROPIC_BASE_URL` to an Anthropic-compatible gateway (LiteLLM, OpenRouter).

## Trigger tests

`evals/skills/<skill>/triggers.json` lists prompts with `should_trigger` true/false (include near-misses that belong to a sibling skill). `triggers.py` installs all skills together, runs each prompt with the Skill and Read tools only, and counts a hit when the skill is called or its SKILL.md read:

```bash
evals/triggers.py --dry-run                    # list queries
evals/triggers.py --model haiku --repeats 3    # all skills
```

`flaky` means it fired on some repeats only: the description is borderline.
