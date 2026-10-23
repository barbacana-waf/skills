# Applying config changes: reload and restart

Verified against a v0.9.7 binary (SIGHUP experiments below), reading `cmd/serve.go`.

**Recommendation: validate, then restart.** `docker compose restart barbacana`, `kubectl rollout restart deployment/barbacana`, `systemctl restart barbacana`. Keep the old instance serving until the new one logs `barbacana started` where the platform allows it (Kubernetes rolling update does). A restart drops in-flight connections and resets rate-limit counters.

## What SIGHUP actually does

On SIGHUP the process re-reads and re-validates the whole file, stores the newly resolved route settings, compiles a proxy config, and asks Caddy to load it. Caddy skips the load when the compiled proxy config is byte-identical to the running one (it logs `config is unchanged`). Only the proxy config carries: the route list and order, route ids, `match` hosts and paths, `rewrite`, upstream URL, the listen `port` and `host` list, and `global.protocol.slow_request_header_timeout`. Everything else lives in the route settings store, which the request handler reads only when Caddy provisions it, so it is applied only if Caddy actually reloads.

Verified results:

| Edit, alone | After SIGHUP |
|---|---|
| route `mode: detect_only` | **not applied** (probe still 403) |
| route `disable: [leaf]` | **not applied** |
| `global.mode`, `global.accept.methods` | **not applied** |
| route `upstream_timeout` | **not applied** (Caddy: "config is unchanged") |
| route upstream URL | applied |
| a new route added | applied, and it also pulls in every other pending route-level edit |
| `audit_log.format` | **never**: fixed at startup |
| `health_port` | **never**: the old port keeps serving, the new one does not open |
| `metrics_port`, `tracing:` block | startup only (read once in `runServe`; not exercised live) |
| `rate_limit`, `accept`, `inspection`, `multipart`, `response_headers`, `openapi`, `cors`, `error_response` | same path as `mode`: applied only if something else changed the proxy config (from code, not exercised one by one) |

So an edit can sit unapplied and then silently take effect later, when a different edit adds a route or changes an upstream. After SIGHUP the process still logs `config reloaded`, increments `waf_config_reload_total{result="success"}`, and `waf_mode_info` shows the file's mode, none of which proves the running behaviour changed.

## What a bad config does on SIGHUP

The process stays up and the old routes keep serving in every case tried:

| Bad edit | Result |
|---|---|
| YAML syntax error | `reload failed` logged with the parse error, `result="error"` +1, nothing changes |
| validation error (for example an unknown protection name in `disable`) | same |
| config that passes `--validate` but fails when the handler starts (missing `openapi.spec`, together with a new route so Caddy actually tries to load) | `reload failed ... create OpenAPI validator`, Caddy rolls back, old routes keep serving, `caddy_config_last_reload_successful` becomes 0. **But** `waf_mode_info` already shows the rejected file's routes and modes. |
| the same missing spec edit made alone | `config reloaded` and success counted; the bad spec is only discovered at the next restart |

At **startup** a bad config exits the process with an error message; on Kubernetes that is a crash loop and the old pod keeps serving during a rolling update, so prefer rollouts over in-place restarts.

## The "reload bug"

Nothing in the repo (TODO, issue, test) records it. This is the finding: SIGHUP reports success but does not apply route-level and global protection settings unless the compiled proxy config also changes, and the reload metrics and `waf_mode_info` give no hint. The repo's smoke test `scripts/minimal-test.sh` (`make test-minimal`) cannot catch it: it fails at startup on v0.9.7 because its config uses `listen:`, `health_listen:` and `metrics_listen:`, keys the current schema rejects, so the reload steps never run (and even if they did, they only check that the log line appears and that a syntax error leaves the process alive). Say this plainly to the user; do not offer to fix the WAF in this skill.

## If the user insists on SIGHUP

`kill -HUP <pid>` (`docker kill -s HUP`, `systemctl reload` is not defined by the shipped unit). Afterwards prove the change by behaviour, never by logs: send the request that the edit should change and look at the status. For a mode or `disable` change, that is the attack probe `?q=%27%20OR%201%3D1--` (403 blocking, 200 detect-only). If the behaviour did not change, restart.
