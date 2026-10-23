# Alerts and dashboards

## Scrape

`assets/prometheus-scrape.yaml` has a static job and a Kubernetes pod-discovery job. Scrape the **metrics port** (not the proxy port, not the health port). Replace the target, and keep the job label `barbacana` or change it in the alert file too.

## Alert rules

`assets/prometheus-alerts.yaml` ships these. Thresholds are starting points; ask the user for their traffic shape before tightening them.

| Alert | Fires when | Notes |
|---|---|---|
| `BarbacanaDown` | scrape target `up == 0` for 2m | the metrics listener is gone or unreachable; also check the process |
| `BarbacanaUpstreamErrors` | more than 5% of a route's requests fail upstream for 5m | the main "is the app down" signal; the health probes will not show it |
| `BarbacanaBlockRatioHigh` | over 30% of a route's requests blocked for 10m, with real traffic | an attack, or a new false positive after a deploy; look at the audit log |
| `BarbacanaRouteDetectOnly` | any route in `detect_only` for 1h | detect-only lets attacks through; make sure it is temporary |
| `BarbacanaEvaluationTimeouts` | any CRS evaluation timeout in 10m | slow or oversized inspection |
| `BarbacanaInFlightHigh` | over 500 requests in the pipeline for 5m | capacity; align with the dashboard's `inflight_crit` |
| `BarbacanaOverheadHigh` | WAF overhead p95 over 100ms for 10m | check body sizes and `inspection` settings |
| `BarbacanaReloadRejected` | `caddy_config_last_reload_successful == 0` for 5m | a SIGHUP was refused after parsing; restart with a fixed config |
| `BarbacanaRestarted` | process start time changed | informational |

Deliberately **not** included: alerts on `waf_config_reload_total{result="success"}` or `waf_mode_info` as proof of a reload (see `metrics.md`), `caddy_reverse_proxy_upstreams_healthy` (always 1), and a "no traffic" alert (depends on the site; add one if the service has constant traffic: `sum(rate(waf_requests_total[10m])) == 0`).

Rate limiting: to see throttling, `sum by (route) (rate(waf_requests_blocked_total{protection="rate-limit"}[5m]))`. A sustained non-zero rate on a login route is normal under attack; on an ordinary route it usually means the limit is too low or `source: ip` is keying on a load balancer.

Check with `promtool check rules assets/prometheus-alerts.yaml` when `promtool` is available. Fire one alert for real in a test environment before calling the work done.

## Grafana

Barbacana ships one dashboard, `dashboards/barbacana.json` in the source repository (`github.com/barbacana-waf/barbacana`, the tag matching the running version). Fetch it from there rather than writing a new one:

1. Grafana, Dashboards, New, Import, upload `barbacana.json`, pick the Prometheus data source.
2. Variables: `Route`, `Protection`, `inflight_warn` (100) and `inflight_crit` (500), `audit_log_url` (a SIEM link template, empty by default).
3. Rows: golden signals, WAF state (mode per route), throughput and latency, errors and upstream, threat detail, operational signals. It needs only `waf_*` series; the `caddy_*` panels degrade to a message when absent.

Its README suggests a `kubectl logs ... | jq 'select(.route == ...)'` drill-down; the audit events do not have a top-level `route` field (it is `metadata.route_id` for OCSF, `labels.route_id` for ECS), so use the recipes in `audit-and-siem.md` instead.

Do not edit the dashboard JSON to chase a panel that shows "no data": check that the metric exists on `/metrics` first (series appear on first use).
