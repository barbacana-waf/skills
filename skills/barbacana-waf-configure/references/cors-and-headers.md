# CORS, response headers, block page

## CORS (opt-in per route)

```yaml
cors:
  allow_origins: ["https://app.example.com"]   # required; exact origins
  allow_methods: [GET, POST]                   # default [GET]
  allow_headers: [Authorization, Content-Type]
  expose_headers: []
  allow_credentials: false
  max_age: 600                                 # seconds, 0 to 86400
```

Verified on v0.9.7 and v0.10.0:
- Preflight (`OPTIONS` with `Origin` and `Access-Control-Request-Method`) from an allowed origin returns 204 with the `Access-Control-*` headers.
- A request from another origin passes through without `Access-Control-Allow-Origin`; the browser, not Barbacana, blocks it.
- If `accept.methods` is set without `OPTIONS`, preflight gets 405.
- `allow_origins: ["*"]` with `allow_credentials: true` fails validation. Use exact origins. If the user insists on `*`, it must be without credentials; say it exposes the API to any website's scripts.

Ask for the origins (scheme + host + port). Do not infer them from `localhost` dev defaults. CORS is per route: repeat the block on each route that needs it. If the upstream app also sets CORS headers, expect duplicates; ask which side owns it.

## Injected security headers

Default on: HSTS, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `X-DNS-Prefetch-Control`. Default off: CSP, COOP, COEP, CORP, Permissions-Policy, Cache-Control (they break apps without tuning). Run `barbacana --catalog` for the list and `--catalog-leaf <id>` for the reasoning.

The **leaf** switches a header on or off; the **value** sits in `response_headers.inject`, keyed by the leaf name:

```yaml
enable: [response-headers-add-csp]
response_headers:
  inject:
    response-headers-add-csp: "default-src 'self'; frame-ancestors 'none'"
```

Verified: a value for an off-by-default leaf is ignored without `enable`; a value for an on-by-default leaf (for example `response-headers-add-hsts: "max-age=300"`) replaces the default. Injected `X-Frame-Options` is `DENY` in v0.9.7 (the catalog text says SAMEORIGIN). Keys other than `response-headers-add-*` fail validation.

- `inject` merges key by key with `global`; a route key overrides the same key.
- To drop one header on one route: `disable: [response-headers-add-frame-options]` on that route (for embeddable pages). That is a legitimate use of `disable` here; state what is lost.
- Before enabling CSP, COOP, COEP or Permissions-Policy, ask whether the app or a CDN already sets them, and offer to start with a narrow route. A strict CSP breaks inline scripts and third-party assets: tell the user to test in a browser. Do not make up a "safe" CSP for an unknown app.
- The catalog text mentions a `route.csp.policy` field; that is outdated. The key does not exist.
- `response_headers.strip_extra: [X-Internal-Id]` removes extra response headers beyond the default strip list (server banners, `X-Powered-By` and similar are already stripped).

## Custom block response

```yaml
error_response:
  body: '{"error":"blocked","request_id":"{{.RequestID}}"}'
```

Only `{{.RequestID}}` and `{{.Timestamp}}` exist. Status code and headers are fixed. Keep the request id in the body: `barbacana-waf-tune` and the audit log need it.
