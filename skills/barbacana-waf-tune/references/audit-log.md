# Reading the audit log

Barbacana writes one JSON document per request to stdout, always on. The format is `ocsf` (default) or `ecs`, set by `audit_log.format`. Find it with `docker compose logs barbacana`, `kubectl -n <ns> logs deploy/barbacana`, or `journalctl -u barbacana -o cat`. Lines that are not audit events (startup, reload) are ordinary slog lines; ignore them.

`scripts/find-event.sh <request_id>` extracts the fields below from either format.

## Fields that matter (verified on v0.9.7)

| What | OCSF | ECS | Both |
|---|---|---|---|
| Request id (same value as the 403 body) | `http_request.uid` | `labels.request_id` | |
| Route | `metadata.route_id` | `labels.route_id` | |
| Protections that matched | | | `barbacana.matched_protections` |
| Weakness class | | | `barbacana.cwe` |
| Outcome | `disposition` (`Blocked` / `Allowed`) | `event.action` (`block`), `event.outcome` | |
| Status returned | `status_code` | `http.response.status_code` | |

`barbacana.matched_rules` and `firewall_rule` / `rule.id` hold CRS rule IDs for SIEM correlation. Do not quote them to the user or write them to config.

## Recipes

```bash
# every blocked request, by route and protection
… | jq -r 'select(.disposition=="Blocked") | [.metadata.route_id, (.barbacana.matched_protections|join(","))] | @tsv' | sort | uniq -c | sort -rn

# the same ranking on ECS
… | jq -r 'select(.event.action=="block") | [.labels.route_id, (.barbacana.matched_protections|join(","))] | @tsv' | sort | uniq -c | sort -rn

# would-have-been blocks while a route is in detect-only (OCSF)
… | jq -c 'select(.disposition=="Allowed" and ((.barbacana.matched_protections // [])|length) > 0)'
```

## Detect-only in the log

On a `detect_only` route a matching request is passed to the upstream and the event has `disposition: "Allowed"`, status 200 and a non-empty `barbacana.matched_protections`. At startup Barbacana logs a warning per such route (`route in detect_only mode — attacks are logged but NOT blocked`). Only the OCSF shape was checked; for ECS look at `event.action` and `event.outcome` and confirm on a real event before relying on them.

## One event, several protections

A blocking-mode event lists every protection that matched before the pipeline halted. After you relax one, the same request may be blocked by the next. Re-test and re-read the log until it passes.
