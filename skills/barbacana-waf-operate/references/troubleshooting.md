# Troubleshooting (v0.10.0)

Read-only checks first. Commands assume you run them where the internal ports are reachable (`kubectl port-forward`, `docker compose exec`, or the host).

## Symptom table

| Symptom | Likely cause | Check |
|---|---|---|
| Container exits right after start, or crash loop | Config rejected at startup (parse error, unknown key, missing `openapi.spec`, port clash) | Logs show a one-line message such as `parse config … field X not found`. `--validate` catches many but not all (a missing OpenAPI spec passes it). |
| `/healthz` connection refused | `health_port` is 0, the process is down, or the port is not published | `grep health_port waf.yaml`; startup log says `health endpoint disabled` when it is 0. |
| `/healthz` is 200 but the site fails | Probes only prove the process is up; they do not check upstream or config | go on to the next rows |
| Empty-body **502** | Upstream unreachable or timing out | `waf_upstream_errors_total{kind=…}` rising: `connection_refused` (wrong host/port, upstream down), `timeout` (raise `upstream_timeout` in configure, or fix the app), `5xx` (the app's own errors). Compare upstream URL in the render with where the app really listens. |
| **403** `{"error":"blocked","request_id":…}` | A protection blocked it | Find the event by `request_id` (`audit-and-siem.md`) and hand off to `barbacana-waf-tune`. A 403 without that body is not from Barbacana. |
| **429** with `Retry-After` | Rate limiter (`rate_limit:`) | see "Rate limiting" below |
| **405** or odd 4xx/5xx on specific methods | `accept.methods` narrowed (OPTIONS dropped breaks CORS preflight) | hand off to `barbacana-waf-configure` |
| Empty 200 for some paths | No route matched (unmatched paths return an empty 200, not 404) | check route order and `match.paths`; configure |
| Config edit "did nothing" after SIGHUP | a startup-only setting (ports, tracing, audit format), or v0.9.7 or older, where SIGHUP applied almost nothing | `reload.md`; restart |
| `up == 0` but traffic is fine | Metrics port blocked, wrong target, or `metrics_port` unset | `curl http://<host>:<metrics_port>/metrics` from the scraper's network |
| No `waf_*` series for a route | No traffic yet (series appear on first use) or route id differs from the one in the query | list `waf_mode_info` for the real route ids |
| Latency up | WAF overhead vs upstream | `histogram_quantile(0.95, sum by (le)(rate(waf_request_duration_overhead_seconds_bucket[5m])))` against `caddy_http_request_duration_seconds`; if overhead is small the upstream is slow. Also `waf_evaluation_timeout_total`, `waf_body_spooled_total`. |
| Memory high | Large bodies / inspection limits | `process_resident_memory_bytes`, `waf_requests_in_flight`; limits belong to configure. |
| Kubernetes pod unready or restarting | Probe on a port that is not set, or a failing startup | `kubectl describe pod`, `kubectl logs --previous`; readiness is always OK once the process runs, so unready means the process or probe port is wrong |
| TLS / certificate errors | Auto-TLS in `host` mode | `data_dir` must be writable and persistent; port 80/443 reachable for validation; see `barbacana-waf-install` |

## Is it Barbacana or the app?

`sum by (route)(rate(waf_requests_total{action="blocked"}[5m]))` is what the WAF refused. `waf_upstream_errors_total` is what the app (or network) failed. Anything left in `caddy_http_request_duration_seconds_count{code=~"5.."}` beyond those is Caddy itself, for example a 502 from a dial failure or 5xx from the upstream (both are in `waf_upstream_errors_total`).

## Startup checks

```bash
barbacana --version
barbacana --config waf.yaml --validate     # expect: config valid
curl -s http://HOST:HEALTH/healthz         # ok  (only if health_port is set)
curl -s http://HOST:METRICS/metrics | grep -E '^waf_(build_info|mode_info)'
```

`scripts/check-instance.sh` does the last three and prints the key counters.

## Rate limiting

- **Spotting it**: 429 responses with `Retry-After`; audit events with `matched_protections: ["rate-limit"]`; `waf_requests_blocked_total{protection="rate-limit"}`. There is no separate rate-limit metric.
- **Measuring a candidate rate**: set the route to `detect_only` with the proposed `rate_limit`, reload or restart, let normal traffic run, then count `waf_requests_total{action="detected"}` / `waf_detected_threats_total{protection="rate-limit"}` per route and look at the audit events' clients. If real users appear, the limit is too low. Then switch the route back to blocking and restart. Detect-only also disables blocking of every other protection on that route: keep it short, prefer staging. Writing the `rate_limit` block is `barbacana-waf-configure`'s job.
- **Caveats to tell the user**: counters live in process memory, so they reset on every restart; each replica counts separately (N replicas allow up to N times the rate); `source: ip` is the connection's address, which is the load balancer behind one, in which case everyone shares one bucket (use `source: header` with a header the proxy sets and sanitises); a client that controls the header can dodge the limit; it is not a hard quota.
- **Everyone is getting 429**: almost always `ip` source behind a proxy, or a `global` limit inherited by routes that should not have it (a route with its own block replaces the global one; no per-route opt-out exists).
