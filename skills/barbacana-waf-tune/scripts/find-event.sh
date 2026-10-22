#!/usr/bin/env bash
# Print the audit event for one request from Barbacana's stdout log.
#   docker compose logs barbacana | scripts/find-event.sh 0xaa77efca8c0
#   scripts/find-event.sh 0xaa77efca8c0 < audit.log
# Works for the ocsf and ecs formats: matches the request id anywhere in the
# line. Prints protections and route; never prints rule IDs.
set -euo pipefail
id=${1:?usage: find-event.sh <request_id> < log}
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
found=0
while IFS= read -r line; do
  case $line in *"$id"*) ;; *) continue;; esac
  # compose/kubectl prefixes a "name  | " before the JSON; strip up to the first {
  json=${line#"${line%%\{*}"}
  if printf '%s' "$json" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$json" | jq -c '{
      request_id: ($id),
      route: (.metadata.route_id // .labels.route_id // null),
      method: (.http_request.http_method // .http.request.method // null),
      path: (.http_request.url.path // .url.path // null),
      status: (.http_request.status_code // .http.response.status_code // .status_code // null),
      protections: (.barbacana.matched_protections // []),
      cwe: (.barbacana.cwe // [])
    }' --arg id "$id"
    found=1
  fi
done
[ $found = 1 ] || { echo "no audit event for $id (wrong instance, or logs rotated?)" >&2; exit 1; }
