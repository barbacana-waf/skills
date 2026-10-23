# Routes and matching

## Deployment mode is set by `host`, `port` and `match.hosts`

| Mode | Config | Result |
|---|---|---|
| 1 | top-level `host: a.example.com` (or a list) | auto-TLS on 443/80; every route serves every host; routes must not set `match.hosts`; no `port` |
| 2 | no `host`; **every** route has `match.hosts` | auto-TLS, one certificate per host; no `port` |
| 3 | `port: 8080` or neither | plain HTTP behind a load balancer; no `host`, no `match.hosts` |

Switching modes is an install/TLS decision, not a route edit: use `barbacana-waf-install`. Host wildcards: `*.example.com` matches `foo.example.com`, not `example.com`.

## Route fields

```yaml
- id: orders                     # lowercase letters, digits, hyphens; unique; shows in audit log and metrics
  match:                         # omit for a catch-all
    hosts: [api.example.com]     # mode 2 only
    paths: ["/orders", "/orders/*"]
  upstream: http://orders:8000   # http:// or https:// with a host; no path suffix needed
  upstream_timeout: 30s          # 1s to 600s
  rewrite: {strip_prefix: /orders, add_prefix: /api}
```

Give every route an explicit `id`; the generated one is derived from the first path and is unstable if the path changes. The `id` is also how `barbacana-waf-tune` and the audit log refer to the route.

## Order matters (verified on v0.9.7)

Routes are evaluated in file order and the first match wins. The schema doc promises "most specific wins", but v0.9.7 does not sort routes. Observed: a catch-all listed first received `/api/` traffic meant for a later `/api/*` route.

Rules:
1. Specific paths first, broader prefixes next, the route with no `match` last.
2. After any edit read `--render-config` and check the `route_id` order of `routes`. Do not paste the JSON to the user.
3. With no catch-all, an unmatched path gets an **empty 200**, not the 404 the schema doc describes. Add a catch-all upstream (or accept that behaviour knowingly).

## Path patterns

- `/api/*` matches `/api/anything` and `/api/a/b/c` (any depth after the slash). It does **not** match `/api`. Write `paths: ["/api", "/api/*"]` when the bare path is valid.
- `**` does not work in v0.9.7 (`/x/**` did not match `/x/a/b/c`). Use a single trailing `/*`.
- Exact path: no wildcard (`/healthz-app`).
- A route with several `paths` shares one upstream and one set of settings.

## Rewrites

Order: `strip_prefix` first, then `add_prefix`. `path` replaces the whole path and makes the other two inert; prefer strip/add.

| Client sends | Config | Upstream sees |
|---|---|---|
| `/api/items` | `strip_prefix: /api` | `/items` |
| `/legacy/x` | `strip_prefix: /legacy`, `add_prefix: /app` | `/app/x` |
| `/api/items` | `path: /v2/all` | `/v2/all` |

OpenAPI validation and audit-log paths: see `openapi.md`; the spec is checked against the rewritten path.

## Upstreams

- Compose: the service name (`http://api:8000`). Kubernetes: the Service DNS name. Not `localhost`, unless Barbacana runs on the same host as a bare binary.
- `https://` upstreams are allowed.
- Several upstream instances: put them behind the platform's load balancer or Service; a route takes a single upstream URL.
- Websocket and streaming behaviour has not been verified here; test before promising it.

## Splitting an endpoint out of a broad route

To give one endpoint different limits or an exception, add a route with a narrower path **above** the broad one, repeating `upstream` and any `rewrite`:

```yaml
- id: export
  match: {paths: ["/api/export"]}
  upstream: http://api:8000
  rewrite: {strip_prefix: /api}
  accept: {max_body_size: 50MB}
- id: api
  match: {paths: ["/api/*"]}
  upstream: http://api:8000
  rewrite: {strip_prefix: /api}
```

Settings do not carry over from the broad route: repeat everything the narrow route should keep (`accept`, `cors`, `response_headers`).
