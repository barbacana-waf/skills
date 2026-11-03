# OpenAPI validation

```yaml
openapi:
  spec: /etc/barbacana/specs/orders.yaml   # OpenAPI 3.x file
  strict: true                             # false = log only
  disable: []                              # openapi-* leaves only
```

## Before editing

1. Get the real spec file. Do not hand-write a spec to make validation pass. Confirm it is OpenAPI 3.x (`openapi: 3.0.x` or `3.1.x`).
2. Decide where it lives at run time: the path is read by the Barbacana process, so in a container it must be mounted (Compose volume, Kubernetes ConfigMap or volume). Use an absolute path to avoid ambiguity.
3. **Run `--validate` where the spec is mounted.** From v0.10.0 it fails on a missing or invalid spec (`load openapi spec ...`); v0.9.7 printed `config valid` and the process then refused to start, so on older releases check the file exists and parses yourself. `--render-config` does not open the spec, so the real test is still starting a dev instance. A failed startup stops the process: keep the old instance running until the new one is ready.

## Paths are matched after the rewrite

With `rewrite: {strip_prefix: /v1}` and a request to `/v1/items`, the spec must declare `/items`. Verified: a spec that declares `/v1/items` returned 404 for `/v1/items`. Align the spec paths with what the upstream sees, or drop the rewrite.

## What a violation returns

| Protection | Status |
|---|---|
| `openapi-path-not-in-spec` | 404 |
| `openapi-method-not-in-spec` | 405 |
| `openapi-parameter-mismatch` | 422 |
| `openapi-body-mismatch` | 422 |
| `openapi-content-type-not-in-spec` | 415 |

Plus `response-inspection-openapi-validation` for response shape. Violations carry the same `{"error":"blocked",...}` body and appear in the audit log with the protection name.

## Rolling out safely

- Start with `strict: false` on one route: violations are logged, nothing is blocked. Read the audit log (see `barbacana-waf-tune` / `references/audit-log.md`), fix the spec or the client, then set `strict: true`.
- Narrow exceptions use `openapi.disable: [openapi-parameter-mismatch]`, not the whole `openapi` block. Removing `openapi` turns the feature off for the route.
- A route with a spec rejects undeclared paths. Put endpoints that are not in the spec (health checks, static files) on their own route without `openapi`, placed before the spec route if their paths overlap.
- `global.openapi.shadow_api_logging: true` (default) logs undeclared paths even if `openapi-path-not-in-spec` is disabled.
