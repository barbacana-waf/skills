---
name: barbacana-waf-operate
description: "Run Barbacana in production: Prometheus metrics and alert rules, health and readiness probes, OCSF/ECS audit logs and SIEM forwarding, OpenTelemetry tracing, Grafana dashboards, rate-limit 429s, config reloads and restarts, troubleshooting a failing, unhealthy or slow instance. Use whenever the user asks to monitor, alert on, debug, reload or maintain a running Barbacana."
---

# Barbacana: operate

Day-2 operations: observe, alert, troubleshoot. Read what the instance reports before changing anything, and say which signals you could not check.

## Ground rules (shared by all Barbacana skills)

- The CLI is flag-only: `barbacana --config <path> --validate`, `--render-config`, `--catalog`, `--catalog-leaf <id>`, `--version`. There are no subcommands.
- After every config edit, run `--validate` and fix what it reports before moving on.
- Use protection names exactly as `barbacana --catalog` prints them. Never invent names.
- Never show or suggest Caddy/Caddyfile syntax or CRS rule IDs. Protection names are the interface.
- Out of scope for Barbacana: IP blocking/allowlisting, CAPTCHA, TLS fingerprinting, volumetric DDoS. Rate limiting is supported (`rate_limit:` per route or in `global:`); route config changes belong to the configure skill.

## What to know before you start

- **Health and metrics are opt-in.** `health_port` and `metrics_port` default to 0 (no listener). If they are off, enabling them is a config change plus a restart; `assets/waf-observability.yaml` shows the keys. Keep both on an internal network: `/metrics` lists route ids and protection names.
- **`/healthz` and `/readyz` only prove the process is up.** Both always return `200 ok`. They do not check the upstream, the config, or whether the last reload took. Never conclude "healthy" from them alone; see `references/troubleshooting.md`.
- **Only blocked or detected requests reach the audit log.** Clean requests are counted in metrics but not logged. A missing event for a request means it matched nothing, not that logging is broken.
- **SIGHUP reload is unreliable in v0.9.7.** It re-reads the file but most edits are not applied, while logs and metrics still say "reloaded". Restart instead. Details in `references/reload.md`.
- Rate limiting has no metric of its own: it shows up as `protection="rate-limit"` on the blocked and detected counters, and as 429 responses.

## Workflow

1. **Take a snapshot.** Find out how Barbacana runs (Compose, Kubernetes, systemd), its version (`barbacana --version` or the image tag), and whether `health_port` and `metrics_port` are set. If the user gave you reachable URLs and says they are safe to query, run `scripts/check-instance.sh <health-url> <metrics-url>`; otherwise ask for the command output. It only issues GET requests to the two internal ports.
2. **Pick the job** and read the matching reference:

   | The user wants | Do | Read |
   |---|---|---|
   | to scrape, graph or alert | add scrape config and alert rules; import the dashboard | `references/metrics.md`, `references/alerts-and-dashboards.md`, `assets/prometheus-*.yaml` |
   | audit logs in a SIEM | choose OCSF or ECS, ship stdout, map fields | `references/audit-and-siem.md` |
   | traces | add the `tracing:` block, verify spans arrive | `references/tracing.md` |
   | to apply a config change | validate, then restart (not SIGHUP) | `references/reload.md` |
   | to know why something is failing, slow or blocked | work the symptom table | `references/troubleshooting.md` |
   | to size or check a rate limit | measure in detect-only, then enforce | `references/troubleshooting.md` (rate limiting) |

3. **Write config and rules to files, then check them.** Edit `waf.yaml` minimally and run `--validate` (it prints `config valid`; ignore the `WARN data_dir does not exist` line outside the container). `--validate` misses things that only fail at startup, so after a restart confirm in the logs that `barbacana started` appears and in metrics that your routes exist. Run `promtool check rules` on alert files if `promtool` is installed; if not, say it was not run.
4. **Prove the signal.** An alert or dashboard that was never fired is a guess. With the user's agreement and only against dev or staging, send one harmless attack probe (`?q=%27%20OR%201%3D1--`, expect 403) and confirm `waf_requests_blocked_total` rose and an audit event appeared. Never send probes, load or restart commands at production without a clear yes.
5. **Report** what you found or set up, what you verified, what you could not, and any follow-up (for example "reload edits need a restart").

## Troubleshooting order

Work from the outside in and stop at the first fault found:

1. Is the process running and did it start? Logs end with `barbacana started`; a startup error is a plain message on stderr and the process exits.
2. Do the metrics answer? If `up == 0` only the scrape is broken, not necessarily the WAF.
3. Is it the WAF or the upstream? Compare `waf_requests_blocked_total` with `waf_upstream_errors_total`. A 502 with an empty body is the upstream being unreachable.
4. A 403 `{"error":"blocked"}` is a WAF decision: hand off to `barbacana-waf-tune` with the `request_id`. A 429 with `Retry-After` is the rate limiter.
5. Slow? Check `waf_request_duration_overhead_seconds` against total latency, and `waf_evaluation_timeout_total`.

## Safety rules

- Do not expose `/metrics`, `/healthz`, the pprof port (`BARBACANA_PPROF_PORT`, off by default, never in production) or raw audit logs beyond the cluster. Audit events contain client IPs, URLs and user agents: treat them as personal data in a SIEM.
- Do not paste CRS rule IDs into answers, alerts or config. The audit log carries them for SIEM correlation; refer to protections by name.
- Do not put tracing credentials (`tracing.headers`) into files in a shared repository; use the platform's secret mechanism.
- Do not turn a route to `detect_only`, disable a protection, or change limits to make an alert go quiet. Those are `barbacana-waf-tune` and `barbacana-waf-configure` decisions.
- Do not send SIGHUP, restart or roll out without telling the user what will happen. A restart drops in-flight connections.

## References

| File | Read when |
|---|---|
| `references/metrics.md` | you need exact metric names, labels and what each really counts, or you will write PromQL |
| `references/alerts-and-dashboards.md` | writing alerts, importing the Grafana dashboard, choosing thresholds |
| `references/audit-and-siem.md` | reading audit events, jq recipes, OCSF vs ECS fields, forwarding to a SIEM |
| `references/tracing.md` | enabling OpenTelemetry tracing, span names, correlating traces with audit events |
| `references/reload.md` | applying config changes, SIGHUP behaviour, which settings need a restart |
| `references/troubleshooting.md` | a symptom: 502, 403, 429, no metrics, slow, restarts, unready pod |
| `assets/waf-observability.yaml` | starting point with health, metrics, audit format and tracing set |
| `assets/prometheus-scrape.yaml`, `assets/prometheus-alerts.yaml` | scrape job and alert rules; replace the job label and thresholds |
| `scripts/check-instance.sh` | one-shot snapshot of probes and key counters |

## Next step

A legitimate request is blocked: `barbacana-waf-tune`. A route, limit, header or rate-limit change: `barbacana-waf-configure`. Install, TLS, ports or upgrades: `barbacana-waf-install`.
