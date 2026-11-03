# Metrics (verified on v0.9.7, names re-checked on v0.10.0)

Served at `http://<host>:<metrics_port>/metrics`, plain HTTP, only when `metrics_port` is non-zero. The endpoint merges Barbacana's `waf_*` series, Caddy's `caddy_*` series and Go/process metrics. There is no authentication.

## Barbacana series

| Metric | Type | Labels | What it counts |
|---|---|---|---|
| `waf_requests_total` | counter | `route`, `action` | Every request. `action` is `allowed`, `detected` (matched but not blocked: detect-only) or `blocked`. |
| `waf_requests_blocked_total` | counter | `route`, `protection` | Blocked requests, by the protection that halted the pipeline. |
| `waf_detected_threats_total` | counter | `route`, `protection` | Matches, in any mode. One request matching three protections adds 3, and blocked requests are included. Counts threats, not requests. |
| `waf_requests_in_flight` | gauge | | Requests currently in the pipeline. |
| `waf_upstream_errors_total` | counter | `route`, `kind` | `timeout`, `connection_refused`, `5xx`, `other`. |
| `waf_anomaly_score_histogram` | histogram | `route` | CRS anomaly score; buckets 1, 2, 3, 5, 10, 15, 25, 50. |
| `waf_request_duration_overhead_seconds` | histogram | `route` | WAF-only time (total minus upstream round trip); default buckets 5ms to 10s. |
| `waf_openapi_validation_total` | counter | `route`, `result` | OpenAPI validation outcomes. |
| `waf_security_headers_injected_total` | counter | `route`, `header` | Injected response headers. |
| `waf_evaluation_timeout_total` | counter | `route` | Rule evaluation timeouts. |
| `waf_body_spooled_total` | counter | `route` | Bodies spooled to disk. |
| `waf_body_inspection_skipped_total` | counter | `route` | Requests forwarded to the upstream without body inspection because the body could not be buffered (fail-open). Expected to stay at zero. Added in v0.10.0. |
| `waf_decompression_rejected_total` | counter | `route` | Requests rejected for decompression ratio. |
| `waf_config_reload_total` | counter | `result` (`success`, `error`) | SIGHUP attempts. See the note below. |
| `waf_config_reload_timestamp_seconds` | gauge | | Time of the last SIGHUP counted as success. 0 until one happens. |
| `waf_crs_rules_loaded_total` | gauge | | Loaded rule count (49 on a default config); a gauge despite the name. |
| `waf_mode_info` | gauge | `route`, `mode` | Always 1; `mode` is `blocking` or `detect_only`. |
| `waf_build_info` | gauge | `version`, `go_version`, `crs_version`, `commit` | Always 1. |

Labels `route` are the route `id`s from `waf.yaml` (auto-generated when omitted). `protection` values are catalog leaf names, plus `rate-limit`.

Series appear on first use: before any traffic a route has no `waf_requests_total` line, so `absent()` alerts and "no data" panels are expected on a fresh instance.

## Caddy and process series

`caddy_http_request_duration_seconds_{bucket,count,sum}` (labelled with `code`, among others), `caddy_http_requests_in_flight`, `caddy_http_request_size_bytes`, `caddy_http_response_size_bytes`, `caddy_reverse_proxy_upstreams_healthy`, `caddy_config_last_reload_successful`, `caddy_config_last_reload_success_timestamp_seconds`, plus `go_*` and `process_*` (including `process_start_time_seconds`, useful to detect restarts). `caddy_http_requests_total` has no `code` label; use the duration `_count` series for status codes.

`caddy_reverse_proxy_upstreams_healthy` stays 1 for an unreachable upstream (no active health checks are configured), so it is not a health signal.

## Things the numbers do not tell you

- **A failed upstream is still `allowed`.** With the upstream down, requests count as `action="allowed"` and also bump `waf_upstream_errors_total{kind="connection_refused"}`. Use the error counter, not `blocked`, for upstream health.
- **Detect-only is `detected`, not `allowed`.** A route in `detect_only` that matches shows `action="detected"` and the request is forwarded. Matches are also in `waf_detected_threats_total`.
- **Rate limiting** has no dedicated series. Over-limit requests appear as `waf_requests_blocked_total{protection="rate-limit"}` (and `detected` in detect-only).
- **Reload metrics on v0.9.7 and older lie.** `waf_config_reload_total{result="success"}` rose on every SIGHUP, including ones where nothing was applied, and `waf_mode_info` was rewritten even when the new config was rejected. From v0.10.0 a successful reload really swaps the routes, but startup-only settings (ports, tracing, audit format) are still ignored while counting as success, so confirm by behaviour. Details: `reload.md`.
- `caddy_config_last_reload_successful` drops to 0 when Caddy rejects a new config at provisioning and stays 0 until the next config that Caddy actually loads. It is the one signal that a SIGHUP was refused after parsing.
- `/metrics` has no per-request detail. Use audit logs for who, what and when.
