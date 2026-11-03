# Rate limiting

Off by default. Add a `rate_limit:` block to a route or to `global:`. Verified on v0.9.7 and v0.10.0.

```yaml
rate_limit:
  requests: 5            # >= 1
  window: 60s            # >= 1s; sliding window per client
  source:
    type: ip             # or header
    key: X-Forwarded-For # required when type is header
  backend:               # optional
    type: memory         # only value; max_keys (default 100000), ttl (default 10m)
```

Over the limit: `429 Too Many Requests` with `Retry-After: <window in seconds>` and the usual `{"error":"blocked","request_id":...}` body. It runs first in the pipeline, before validation, and shows in the audit log as `rate-limit`.

## Choosing the source

- `ip`: the connection's remote address. Right only when Barbacana is the edge (it terminates TLS). Behind a load balancer every request comes from the balancer and all clients share one bucket.
- `header`: the value of the named header is the client key. Behind a proxy use `X-Forwarded-For`/`X-Real-IP`; for per-key limits use `X-Api-Key` or `Authorization`.
- If the header is absent, the limiter falls back to the connection IP (and logs a warning). Verified: three header-less requests gave 200, 200, 429 as one shared bucket.
- Barbacana does not strip client-sent headers. **A header source is only safe when the proxy sanitises it** (overwrites `X-Forwarded-For`; an authenticating gateway sets the key). Otherwise a client rotates the value and bypasses the limit. Ask the user how the proxy treats the header before choosing it.

## Global default and route override

- A route block **replaces** the global block entirely, with no field merging; repeat `source` and `window` in the route.
- A route without its own block inherits the global one. There is no opt-out. If some routes must stay unlimited, put `rate_limit` on the routes that need it and leave `global` without one.
- Each client has its own counter per route.

## Detect-only

On a route with `mode: detect_only` (or `global.mode`), over-limit requests are forwarded and logged as detected. Verified: three requests to a route with limit 1 all returned 200. Use it to measure traffic before enforcing, and set the route back to blocking afterwards.

## Limits of the feature

- Counters live in process memory and reset on restart.
- Each replica counts separately: with N replicas a client can make up to N times `requests` per `window`.
- It slows attackers (login throttle, credential stuffing, scraping); it is not a quota or billing system. Do not promise exact contractual limits.
- Pick numbers from the user's real traffic; do not invent them. Common starting points are a login endpoint at 5 per minute per client, and a general default well above normal browsing.
- Restart Barbacana after the edit, like other config changes.
