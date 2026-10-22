---
name: barbacana-waf-configure
description: "Write and change Barbacana YAML configuration: routes and path matching, upstreams, path rewrites, CORS, security headers, file uploads, size and content-type limits, OpenAPI validation, per-team routes.d files. Use whenever the user wants to add or edit a route, change what Barbacana accepts, or review a waf.yaml."
metadata:
  internal: true  # hidden from skills.sh/CLI discovery until the skill is finished
---

# Barbacana: configure

Edits waf.yaml safely using the edit, validate, render loop.

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
