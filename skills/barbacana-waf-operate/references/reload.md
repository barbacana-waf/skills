# Applying config changes: reload and restart

Checked against a v0.10.0 binary (SIGHUP experiments below) and `cmd/serve.go`. **Releases up to v0.9.7 behave differently**: SIGHUP re-read the file but silently applied almost nothing, while logging `config reloaded`. Run `barbacana --version` (or read the image tag) first; on v0.9.7 or older, validate and restart instead.

## v0.10.0: SIGHUP reloads routes and rolls back on failure

`kill -HUP <pid>` (`docker kill -s HUP <container>`; `systemctl reload` is not defined by the shipped unit). The process re-reads and re-validates the file, builds the new routes, and swaps them in. If anything fails, the old config keeps serving.

| Edit, alone | After SIGHUP (tested) |
|---|---|
| route `mode: detect_only` or `global.mode: detect_only` | applied; `waf_mode_info` follows |
| `accept.methods` | applied |
| route list, upstream, `match`, `rewrite` | applied |
| `health_port`, `metrics_port` | **not applied**; the old port keeps serving, the new one never opens |
| `audit_log.format`, `tracing:` block | **not applied**; restart |
| anything else under a route | same path as `mode`; expect it to apply, and confirm by behaviour |

Startup-only settings are ignored without an error: the log still says `config reloaded`. The v0.10.0 release notes say these produce a warning; none appeared in testing, so do not rely on one.

## What a bad config does on SIGHUP

The process stays up and the old routes keep serving:

| Bad edit | Result |
|---|---|
| YAML syntax or validation error | `reload failed` with the reason, `waf_config_reload_total{result="error"}` +1 |
| a missing `openapi.spec` | `reload failed`, Caddy rolls back, old routes keep serving (older releases reported success and failed at the next restart) |

At **startup** a bad config exits the process with an error message. On Kubernetes that is a crash loop while the old pod keeps serving during a rolling update, so prefer rollouts over in-place restarts for startup-only settings.

## Workflow

1. Edit, then `barbacana --config waf.yaml --validate`.
2. Route or protection change on v0.10.0: SIGHUP, then check the log for `config reloaded` or `reload failed`.
3. **Prove it by behaviour, not by logs.** Send the request the edit should change and check the status. For a mode or protection change that is the attack probe `?q=%27%20OR%201%3D1--` (403 blocking, 200 detect-only).
4. Port, tracing or audit-format change, or an older release: restart (`docker compose restart barbacana`, `kubectl rollout restart deployment/barbacana`, `systemctl restart barbacana`). A restart drops in-flight connections and resets rate-limit counters.
5. Tell the user which of the two you used and what you checked.
