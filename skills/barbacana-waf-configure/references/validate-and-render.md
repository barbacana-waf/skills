# Validate and render

```bash
barbacana --config waf.yaml --validate        # prints "config valid" on success, exit 0
barbacana --config waf.yaml --render-config   # compiled JSON; read route order, matchers, rewrites, upstreams
barbacana --catalog                           # protection names; --catalog-leaf <id> for one
```

In a container, mount the config and run the image with the same flags. Both commands also print a harmless `WARN data_dir does not exist` line if `/data/barbacana` is absent on the machine; ignore it, or set `data_dir` to a real writable directory.

`--validate` loads the file strictly, so a misspelled key is an error. Messages name the field. Common ones:

| Message contains | Cause and fix |
|---|---|
| `field X not found in type config.Route` | key not valid there (typo, wrong level, or `protocol:` on a route) |
| `unknown protection "..." (did you mean ...?)` | wrong protection name; copy from `--catalog` |
| `duplicate route id` | ids must be unique and match `^[a-z0-9][a-z0-9-]*$` |
| `upstream: scheme must be http or https` | write `http://host:port` |
| `match.paths: "..." must start with /` | add the leading slash |
| `accept.max_body_size must be > 0 and <= 1GB` | out of range; ranges are in `limits-and-uploads.md` |
| `multipart.file_limit must be >= 1` | set a positive number |
| `cors.allow_credentials is true but allow_origins contains "*"` | list exact origins |
| `"port" and "match.hosts" ... mutually exclusive` | pick one deployment mode (`routes-and-matching.md`) |
| `routes: at least one route is required` | the file needs a route |
| `protection ... appears in both disable and enable lists at the same scope` | remove one |
| `response-headers ... not a known protection name` / `must be a canonical response-headers-add-* name` | `inject` key must be a `response-headers-add-*` leaf |

## What validation cannot tell you

Missing OpenAPI spec files, route order, whether a header value will take effect, and whether paths overlap are not checked. Use the checks in `SKILL.md`.

## Where a setting goes

- `global:` applies to every route: mode, `disable`/`enable`, `accept`, `inspection`, `multipart`, `protocol`, `response_headers`, `openapi.shadow_api_logging`.
- Route level: `id`, `match`, `upstream`, `upstream_timeout`, `rewrite`, `mode`, `disable`, `enable`, `accept`, `inspection`, `multipart`, `response_headers`, `openapi`, `cors`, `error_response`.
- Top level: `version`, `host`/`port`, `data_dir`, `metrics_port`, `health_port`, `routes_dir`, `tracing`, `audit_log`.

Prefer the route level. A global change affects every route, including ones the user did not mention.
