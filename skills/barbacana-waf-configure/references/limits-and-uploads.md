# Limits, content types and uploads

All `accept`, `inspection` and `multipart` keys can be set in `global:` and overridden per route. Unset route keys inherit. Per-route `protocol:` does **not** exist (config is rejected); `protocol` is global only.

## `accept`

```yaml
accept:
  methods: [GET, POST]               # default: GET POST PUT PATCH DELETE HEAD OPTIONS
  content_types: [application/json]  # default: all
  max_body_size: 1MB                 # default 10MB, max 1GB
  max_url_length: 8192               # 512 to 65536
  max_header_size: 16KB              # 4KB to 1MB
  max_header_count: 100              # 10 to 1000
```

Sizes take `B`, `KB`, `MB`, `GB` (powers of 1024). Observed statuses (v0.9.7):

| Condition | Status |
|---|---|
| method not in `methods` | 405 |
| `Content-Type` not in `content_types` (on requests with a body) | 415 |
| body over `max_body_size` | 413 |

- `content_types` also selects which parsers inspect the body. `[application/json]` skips XML, form and multipart parsing, so tighten it wherever the endpoint takes one type only. Match the app's real types (`application/json`, `application/x-www-form-urlencoded`, `multipart/form-data`); do not add types "just in case".
- Narrowing `methods` removes `OPTIONS` unless you list it, which breaks CORS preflight (405). Keep `OPTIONS` on any route with `cors`.
- `max_body_size` is per request, for the whole body including multipart overhead.

## Uploads

Multipart rules only act when `accept.content_types` includes `multipart/form-data`.

```yaml
accept:
  methods: [POST]
  content_types: [multipart/form-data]
  max_body_size: 60MB       # at least file_limit x file_size, plus overhead
multipart:
  file_limit: 5             # files per request, >= 1
  file_size: 10MB           # per file
  allowed_types: [image/png, image/jpeg, application/pdf]   # MIME of each file part; empty = any
  double_extension: true    # reject names like shell.php.jpg
```

Real uploads usually send JSON metadata or form fields alongside the file; if the same endpoint takes `application/json`, list both types. `allowed_types` checks the declared MIME of each part, not the file's bytes: say so, and keep server-side content checks in the app. Enforcement is by protections under `file-upload-limits-*` (run `barbacana --catalog-leaf <id>` to describe one); do not disable them to make an upload work, raise the specific limit instead. If an upload with sane limits is still blocked, hand off to `barbacana-waf-tune`.

## `inspection`

Bounds for body inspection. Raise only for a proven need (a big JSON API, a GraphQL endpoint), per route, with the number the app actually needs.

| Key | Default | Range |
|---|---|---|
| `max_inspect_size` | 128KB | up to 10MB; bytes of body evaluated by rules |
| `json_depth` | 20 | 1 to 1000 |
| `json_keys` | 1000 | 1 to 100000 |
| `xml_depth`, `xml_entities` | 20, 100 | only used if XML is accepted |
| `decompression_ratio_limit` | 100 | >= 1 |
| `evaluation_timeout` | 50ms | >= 10ms |

Data larger than `max_inspect_size` is not fully evaluated. Say so when raising `max_body_size` on a route that takes JSON or forms rather than file parts.
