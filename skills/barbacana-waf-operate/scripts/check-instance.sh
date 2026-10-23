#!/usr/bin/env bash
# Snapshot of a running Barbacana: probes and the counters that matter.
#   scripts/check-instance.sh http://127.0.0.1:8081 http://127.0.0.1:9090
# GET requests to the health and metrics ports only; nothing is sent through the proxy.
set -uo pipefail
health=${1:?usage: check-instance.sh <health-url> <metrics-url>}
metrics=${2:?usage: check-instance.sh <health-url> <metrics-url>}
for p in healthz readyz; do
  printf '%-8s %s\n' "$p" "$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$health/$p")"
done
echo "(both probes only prove the process is up; they ignore the upstream and config)"
body=$(curl -s -m 5 "$metrics/metrics") || true
[ -n "$body" ] || { echo "no metrics from $metrics/metrics (metrics_port unset or unreachable)"; exit 1; }
echo
for m in waf_build_info waf_mode_info waf_requests_total waf_requests_blocked_total \
         waf_upstream_errors_total waf_evaluation_timeout_total waf_requests_in_flight \
         waf_config_reload_total caddy_config_last_reload_successful process_start_time_seconds; do
  printf '%s\n' "$body" | grep -E "^${m}[ {]" || echo "$m: (no series yet)"
done
