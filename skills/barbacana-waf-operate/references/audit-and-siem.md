# Audit logs and SIEM (verified on v0.9.7; event fields re-checked on v0.10.0)

Events are one JSON document per line on **stdout**, interleaved with ordinary operational lines (Barbacana's slog lines and Caddy's lines, which have `level`). Pick events by their shape, not by line position. Format: `audit_log.format: ocsf` (default) or `ecs`, read **once at startup** (a SIGHUP does not change it).

An event is written only when a request **matched at least one protection**: blocked requests (`Blocked`/`block`) and detect-only matches. Clean requests, and requests that only fail upstream, produce no event. The 403/429 body carries `request_id`, which equals the event's id field.

## Fields

| What | OCSF | ECS |
|---|---|---|
| request id | `http_request.uid` | `labels.request_id` |
| route | `metadata.route_id` | `labels.route_id` |
| time | `time` (epoch ms) | `@timestamp` |
| outcome | `disposition` (`Blocked`, `Allowed`) | `event.action` (`block`, `allow`), `event.outcome` |
| status | `status_code` | `http.response.status_code` |
| protections | `barbacana.matched_protections` | same |
| weakness classes | `barbacana.cwe` | same |
| client | `src_endpoint.ip`, `.port` | `client.ip`, `.port` |
| method, path, URL | `http_request.http_method`, `.url.path`, `.url.url_string` | `http.request.method`, `url.path`, `url.full` |
| trace correlation (when `tracing.enabled`) | `metadata.trace_id`, `metadata.span_id` | `trace.id`, `span.id` |

CRS rule ids are in `barbacana.matched_rules` and `firewall_rule`/`rule.id` for SIEM correlation only; do not copy them into answers or config.

Detect-only: the event has `Allowed`/`allow` with a non-empty `matched_protections`, and the status shown is 200 even when the upstream answered something else. Rate-limit events have `matched_protections: ["rate-limit"]`, `cwe: ["CWE-400","CWE-770"]`, status 429 when blocking.

Stand-alone event extraction by request id: `barbacana-waf-tune`'s `scripts/find-event.sh` works on both formats.

## jq recipes (events only; drop other lines with `fromjson?`)

```bash
# top blocked protections per route, OCSF
… | jq -R -r 'fromjson? | select(.disposition=="Blocked") | [.metadata.route_id, (.barbacana.matched_protections|join(","))] | @tsv' | sort | uniq -c | sort -rn
# same, ECS
… | jq -R -r 'fromjson? | select(.event.action=="block") | [.labels.route_id, (.barbacana.matched_protections|join(","))] | @tsv' | sort | uniq -c | sort -rn
# top client IPs for blocked requests, OCSF
… | jq -R -r 'fromjson? | select(.disposition=="Blocked") | .src_endpoint.ip' | sort | uniq -c | sort -rn | head
# rate-limit events
… | jq -R -c 'fromjson? | select((.barbacana.matched_protections // []) | index("rate-limit"))'
```

`… ` is `docker compose logs --no-log-prefix barbacana`, `kubectl logs deploy/barbacana`, or `journalctl -u barbacana -o cat`.

## Shipping to a SIEM

- Collect container stdout with the platform's agent (Fluent Bit, Vector, Filebeat, the Splunk or Datadog agent). The documents are single-line JSON, so line-based tailers work.
- **Filter operational lines at the collector**: keep lines that parse as JSON and have `class_uid` (OCSF) or `event.dataset == "barbacana.audit"` (ECS). Caddy's own lines (`"logger":...`) are not audit events.
- Choose ECS for Elastic/OpenSearch (it is the native schema), OCSF for Splunk, Amazon Security Lake and OCSF-aware tools. Changing the format means a restart.
- Index by `route_id` and `matched_protections`; alert in the SIEM on bursts of one client IP across routes (the WAF itself does no IP blocking).
- Events contain client IPs, URLs (including query strings, which can hold tokens) and user agents. Set retention and access in the SIEM accordingly; Barbacana does not redact.
- Log volume tracks attacks and detect-only matches, not traffic; a route left in `detect_only` can be very noisy.
