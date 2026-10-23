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
3. Runs `claude -p` headless with the eval prompt. Both arms get the same sandbox note (no Docker, cluster or services; write files, describe commands), the same read/write tools, and only `barbacana` and `gh release list` as shell commands. `--setting-sources project` keeps your personal skills out of the run.
4. Grades the files and the final answer with `grade.py` and prints a with/without table.

## Run it

```bash
# a barbacana binary for the validate_config assertions (release archive, or `make build` in barbacana-waf/barbacana)
export BARBACANA_BIN=/path/to/barbacana

evals/run.sh --dry-run                          # show what would run, no API calls
evals/run.sh --skill barbacana-waf-install          # all evals, both arms
evals/run.sh --skill barbacana-waf-install --eval 4 --only with --iteration 2 --model <model-id>
```

Flags: `--budget USD` caps each run (default 1.50). Results land in `evals/workspace/iteration-N/<skill>/eval-<id>/<arm>/`: `workdir/` (what the agent wrote), `response.md`, `transcript.json`, `timing.json`, `grading.json` (`text` / `passed` / `evidence` per assertion, the shape `skill-creator`'s viewer expects). Use a new `--iteration` number after each skill change and compare tables.

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
| `validate_config` | every matching file with `version: v1alpha1` passes `barbacana --validate`, and there is at least one |
| `output_contains` / `output_not_contains` | `regex` does / does not match the final answer |

## Adding an eval

Add an entry to the skill's `evals.json` with a realistic prompt and 4-10 assertions. Prefer asserting on files and on facts the answer must contain; avoid asserting exact wording. Put any project the prompt refers to under `files/<id>/`. Then write the passing case into `selftest/` if the new assertion types need regression coverage.

## Known limits

- Assertions check outcomes, not the path taken. A pass does not prove the agent followed the skill's steps; read a few `transcript.json` files.
- The Kubernetes Service check is a regex over the manifest, not a parsed object model.
- Trigger quality (does the description fire on the right prompts) is a separate test, not covered here. Use `skill-creator`'s description optimizer with near-miss negatives.
- One sample per eval is noisy. Repeat important comparisons with several iterations.
