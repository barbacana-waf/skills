---
name: barbacana-waf-tune
description: "Fix Barbacana WAF false positives: a legitimate request is blocked (403 {\"error\":\"blocked\"}), a route needs detect-only mode, or a protection must be disabled or enabled. Use whenever the user says the WAF blocks a real user, a form, search box, upload or API call returns 403 from Barbacana, they want to reduce false positives, or they ask to disable a protection or turn the WAF to detect-only, even if they name no specific protection."
---

# Barbacana WAF: tune false positives

Find which protection blocked a legitimate request, relax the narrowest thing that fixes it, and prove the WAF still blocks real attacks. Never silence a whole family to fix one request.

## Ground rules (shared by all Barbacana skills)

- The CLI is flag-only: `barbacana --config <path> --validate`, `--render-config`, `--catalog`, `--catalog-leaf <id>`, `--version`. There are no subcommands.
- After every config edit, run `--validate` and fix what it reports before moving on.
- Use protection names exactly as `barbacana --catalog` prints them. Never invent names, and never guess a name from the payload: read it from the audit log.
- Never show or suggest Caddy/Caddyfile syntax or CRS rule IDs. The audit log and catalog contain rule IDs for SIEM use; do not copy them into configs, comments or your answer. Protection names are the interface.
- Out of scope for Barbacana: rate limiting, IP blocking, CAPTCHA, TLS fingerprinting. Say so instead of improvising.

## Workflow

1. **Confirm Barbacana blocked it.** A Barbacana block returns 403 with body `{"error":"blocked","request_id":"..."}`. A 403 without that body comes from the app or another proxy; stop and say so. Get the `request_id` from the user, or reproduce the request with `curl` (ask before sending requests to anything but a dev or staging URL).
2. **Find the audit event.** One JSON line per request goes to stdout (`docker compose logs`, `kubectl logs`, `journalctl -u barbacana`). Run `scripts/find-event.sh <request_id>` on that output, or follow `references/audit-log.md`. Read `matched_protections` and the route. A request can match several protections; handle every one listed.
3. **Judge the request before touching config.** Ask: is this input legitimate? Run `barbacana --catalog-leaf <name>` for each matched protection and compare "What it does" with the actual request. If the request contains something that looks like a real attack (SQL, script tags or shell commands that the user's feature would never send), do not disable anything: explain what the protection saw and ask for a legitimate sample. A user's annoyance with 403s is not evidence of a false positive.
4. **Pick the narrowest fix**, in this order (details in `references/scoping-and-precedence.md`):
   1. Fix the sender if it is easy (for example, stop sending a raw SQL snippet in a free-text field).
   2. If the protection is not an injection check (size limit, content type, method, OpenAPI), change the route's `accept` or `openapi` settings; that belongs to `barbacana-waf-configure`.
   3. `disable: [<leaf>]` on the one route that needs it. If the path currently falls under a broader route, add a route with a narrower `match.paths` for just that endpoint (same upstream) and put the `disable` there.
   4. A global leaf-level `disable` only when the same false positive appears on every route.
   5. Never a bucket or family (`sql-injection`, `sql`) unless the user explicitly accepts losing everything in it, after you list the leaves it covers.
5. **Need data first? Use detect-only, briefly.** When there are many unknown false positives, set `mode: detect_only` on **one** route, collect events (a 200 with a non-empty `matched_protections` is a would-have-been block), derive the leaf list, then return the route to blocking. Detect-only lets attacks through on that route, so keep it short, say that plainly, and prefer staging. Do not set it globally to make 403s go away.
6. **Apply and restart.** Edit `waf.yaml`, add a comment above the change saying why and what it gives up, run `--validate`, then **restart** Barbacana. Do not rely on a SIGHUP reload: in v0.9.7 it reports "config is unchanged" and does not apply route-level `mode` or `disable` edits. Compose: `docker compose restart barbacana`; Kubernetes: `kubectl rollout restart deployment/barbacana` (a changed ConfigMap needs it); systemd: `systemctl restart barbacana`.
7. **Verify both directions.**
   - The original request now succeeds.
   - A harmless probe on the same route still gets a 403: `?q=%27%20OR%201%3D1--`. If it now passes, the change is too broad; narrow it.
   - Re-read the audit log for new events: another protection may have been hiding behind the first.
8. **Report.** One line per change: route, protection, why, what it no longer catches (from the catalog's "What it does"), and how to revisit it. Mention the change is now permanent until someone removes it.

## References

| File | Read when |
|---|---|
| `references/audit-log.md` | reading events, jq recipes, OCSF vs ECS, how detect-only looks |
| `references/scoping-and-precedence.md` | choosing route vs global, `disable` and `enable` precedence, default-off protections |
| `references/common-false-positives.md` | the app type suggests a likely cause (search box, rich text, JSON API) |
| `assets/waf-disable-leaf.yaml`, `assets/waf-detect-only.yaml` | starting points for the two kinds of change |
| `scripts/find-event.sh` | pulling one request's audit event out of a log |

## Next step

For size limits, content types, uploads, CORS or new routes use `barbacana-waf-configure`. To watch blocked and detected counts over time use `barbacana-waf-operate`.
