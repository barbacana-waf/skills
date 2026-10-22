# Barbacana skills

Agent skills that let an AI coding agent install, configure, tune and operate [Barbacana](https://github.com/barbacana-waf/barbacana), the open-source WAF and API security gateway. They work with Claude Code, Codex, Cursor, OpenCode and the other agents supported by the [`skills`](https://github.com/vercel-labs/skills) CLI, and are listed on [skills.sh](https://www.skills.sh/).

## Skills

Named `barbacana-waf-*` so the product category is visible in the skills.sh list and in agent skill pickers.

| Skill | What the agent can do with it | Status |
|---|---|---|
| [`barbacana-waf-install`](skills/barbacana-waf-install) | Put Barbacana in front of an app (Docker Compose, Kubernetes, bare binary + systemd), pick TLS mode, pin and verify a release, smoke-test it | Ready (v0.1) |
| `barbacana-waf-configure` | Add and change routes, headers, CORS, uploads and limits using a validate loop | Planned |
| [`barbacana-waf-tune`](skills/barbacana-waf-tune) | Find which protection blocked a legitimate request from the audit log and relax the narrowest thing that fixes it, never a whole family | Ready (v0.1) |
| `barbacana-waf-operate` | Monitoring, alerting, audit logs, troubleshooting | Planned |

Planned skills are hidden from install (`metadata.internal: true`) until they are finished.

## Install

```bash
npx skills add barbacana-waf/skills                                   # pick interactively
npx skills add barbacana-waf/skills --skill barbacana-waf-install         # one skill
npx skills add barbacana-waf/skills --skill barbacana-waf-install --agent claude-code --global
```

The CLI sends anonymous install telemetry. Set `DISABLE_TELEMETRY=1` to opt out.

## Use

Ask your agent in plain language, for example:

- "Put a WAF in front of the Flask service in this directory. TLS is handled by our load balancer."
- "Deploy Barbacana on my VPS so https://shop.example.com is protected."
- "Set up Barbacana in front of the `orders` service and make sure Prometheus can scrape it."

The skill makes the agent propose each step, validate the config with `barbacana --validate` before running anything, pin a release version, and finish with a smoke test.

## Design rules

- **Query, don't memorise.** Skills tell the agent to run `barbacana --catalog`, `--catalog-leaf <id>` and `--validate` instead of hardcoding protection names or schema fields, so they stay correct as Barbacana changes.
- **Barbacana's contract holds.** The CLI is flag-only (no subcommands). Skills never expose Caddy or CRS rule IDs; protections are referred to by their catalog names.
- **Honest scope.** No rate limiting, IP blocking or CAPTCHA advice, because Barbacana does not provide them.
- **Safe defaults.** Pinned versions, no `disable` entries at install, metrics and health ports kept internal.

## Repository layout

```
skills/<name>/
├── SKILL.md        # triggers + workflow (under 500 lines)
├── references/     # loaded on demand
├── assets/         # sample configs and manifests (validated against a released Barbacana)
└── evals/          # evals.json (prompts + assertions) and fixture projects
evals/              # harness to reproduce the evals, with and without the skill
template/           # starting point for a new skill
scripts/            # lint-skills.sh
docs/PUBLISHING.md  # publishing to skills.sh and releasing updates
```

## Development

```bash
scripts/lint-skills.sh                              # frontmatter and size checks
BARBACANA_BIN=/path/to/barbacana evals/selftest.sh  # grader self-test, no API calls
evals/run.sh --skill barbacana-waf-install --dry-run    # see what an eval run would do
```

How the evals work, their limits, and how to add one: [evals/README.md](evals/README.md). To add a skill, copy `template/`, keep sample configs valid, add evals, and follow the checklist in [docs/PUBLISHING.md](docs/PUBLISHING.md).

First eval results for `barbacana-waf-install` (8 subagent runs, one sample each): 29/29 assertions with the skill, 21/29 without. The differences were on Kubernetes metrics exposure and refusing to disable a whole protection family at install time. Treat this as a first read, not a benchmark.

## License

Apache-2.0, same as Barbacana.
