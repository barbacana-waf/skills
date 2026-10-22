---
name: barbacana-waf-operate
description: "Run Barbacana in production: Prometheus metrics, health and readiness probes, OCSF/ECS audit logs, OpenTelemetry tracing, Grafana dashboards, SIEM integration, config reloads, troubleshooting a failing or unhealthy instance. Use whenever the user asks to monitor, alert on, debug or maintain a running Barbacana."
metadata:
  internal: true  # hidden from skills.sh/CLI discovery until the skill is finished
---

# Barbacana: operate

Day-2 operations: observe, alert, troubleshoot.

## Ground rules (shared by all Barbacana skills)

- The CLI is flag-only: `barbacana --config <path> --validate`, `--render-config`, `--catalog`, `--catalog-leaf <id>`, `--version`. There are no subcommands.
- After every config edit, run `--validate` and fix what it reports before moving on.
- Use protection names exactly as `barbacana --catalog` prints them. Never invent names.
- Never show or suggest Caddy/Caddyfile syntax or CRS rule IDs. Protection names are the interface.
- Out of scope for Barbacana: rate limiting, IP blocking, CAPTCHA, TLS fingerprinting. Say so instead of improvising.

## Workflow

TODO: draft after the interview step.

## References

TODO: list files under `references/` and when to read each.

## Next step

TODO: hand-off to the next skill in the journey.
