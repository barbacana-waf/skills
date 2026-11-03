---
name: barbacana-waf-configure
description: "Write and change Barbacana YAML configuration: routes and path matching, upstreams, path rewrites, CORS, security headers, file uploads, size and content-type limits, OpenAPI validation, per-team routes.d files. Use whenever the user wants to add or edit a route, change what Barbacana accepts, or review a waf.yaml."
---

# Barbacana: configure

Changes `waf.yaml` in small steps, proves each step with `--validate` and `--render-config`, and checks real behavior before calling it done. Read the config before editing it; never rewrite a file from scratch.

## Ground rules (shared by all Barbacana skills)

- The CLI is flag-only: `barbacana --config <path> --validate`, `--render-config`, `--catalog`, `--catalog-leaf <id>`, `--version`. There are no subcommands.
- After every config edit, run `--validate` and fix what it reports before moving on.
- Use protection names exactly as `barbacana --catalog` prints them. Never invent names.
- Never show or suggest Caddy/Caddyfile syntax or CRS rule IDs. Protection names are the interface.
- Out of scope for Barbacana: IP blocking/allowlisting, CAPTCHA, TLS fingerprinting, volumetric DDoS. Rate limiting is supported (`rate_limit:` per route or in `global:`); route config changes belong to the configure skill.

## Workflow

1. **Read first.** Open the existing `waf.yaml` and note the mode (`host` = auto-TLS, `port` = plain HTTP, or `match.hosts` on every route), route ids, and any `global:` block. Run `barbacana --version`; this skill is written for v0.10.x. New files use `version: v1beta1`; `v1alpha1` is deprecated but still accepted, so keep an existing file's `version:` unless asked. On v0.9.7 or older, `v1beta1` is rejected: use `v1alpha1` there, and expect the older behaviour noted in the references. If the user has no config yet, use `barbacana-waf-install` first.
2. **Pin down the change.** Ask only what you cannot infer: which path(s), which upstream, which methods/content types the endpoint really takes, and for CORS the exact origins. Prefer a narrow route for the one endpoint over loosening `global`. Do not guess origins, sizes or spec paths; ask for the real ones or read them from the app's code and docs.
3. **Edit.** Smallest change that does the job, a comment above anything non-obvious. Start from `assets/` when adding a new kind of route:

   | Task | Start from | Detail |
   |---|---|---|
   | new route, prefix, rewrite | `assets/waf-routes.yaml` | `references/routes-and-matching.md` |
   | body size, methods, content types, uploads | `assets/waf-uploads.yaml` | `references/limits-and-uploads.md` |
   | CORS, security headers, CSP | `assets/waf-cors-headers.yaml` | `references/cors-and-headers.md` |
   | OpenAPI validation | `assets/waf-openapi.yaml` | `references/openapi.md` |
   | rate limiting (login throttle, per-key limit) | `assets/waf-rate-limit.yaml` | `references/rate-limit.md` |
   | per-team `routes.d` files | none | `references/routes-d.md` (read before promising anything) |

4. **Validate.** `barbacana --config waf.yaml --validate` must print `config valid`; fix errors using the message, which names the field. Unknown keys are rejected, and a key valid at `global:` may not exist per route (for example `protocol:`). `references/validate-and-render.md` lists the common errors. `--validate` does **not** catch everything: see the next step.
5. **Render and read the result.** `barbacana --config waf.yaml --render-config` prints compiled JSON. Use it only to confirm which routes exist, in what order, with which path matchers, rewrite and upstream; do not show or explain its contents to the user. Then run the checks below that apply to your change.
6. **Test behavior** against a dev or staging instance, with `curl`, only if the user confirms it is safe to send requests. Expected statuses are in the references. Always include one request that must still be blocked: `?q=%27%20OR%201%3D1--` should return 403.
7. **Apply.** From v0.10.0, `kill -HUP` (or `docker kill -s HUP`) applies route and protection edits and keeps the old config if the new one fails; confirm by sending the request the edit should change. Ports, tracing and the audit format are startup-only: restart (`docker compose restart barbacana`, `kubectl rollout restart deployment/barbacana`, `systemctl restart barbacana`). On v0.9.7 or older, always restart: SIGHUP applied almost nothing. See `barbacana-waf-operate` for the details. A config that fails at startup stops the process, so keep the old container or unit running until the new one reports ready.
8. **Report.** One line per change: route, what it now accepts or sends, and anything that is now looser than before.

## Checks that `--validate` does not do (v0.10.0)

- **Route order is evaluation order; a catch-all listed first swallows everything.** Put specific `match.paths` routes first and the route without `match` last. Confirm the order in the render.
- **An unmatched path returns an empty 200**, not 404, when no route matches. Keep a catch-all route unless the user wants that.
- **Path globs:** `/api/*` matches everything below `/api/` at any depth but not `/api` itself; list both `/api` and `/api/*` when the bare path is valid. Do not use `**`; it does not match.
- **`openapi.spec` must exist where Barbacana runs.** From v0.10.0 `--validate` fails on a missing or invalid spec, so run it where the file is mounted; v0.9.7 printed `config valid` and then refused to start. Check the file is present, parses, and is mounted into the container.
- **Header values need their leaf enabled.** A value under `response_headers.inject` is silently ignored until the matching `response-headers-add-*` leaf is in `enable`, if that leaf is off by default (see the catalog).
- **Narrowing `accept.methods` drops `OPTIONS`**, which breaks CORS preflight (405). Include `OPTIONS` on routes with `cors`.
- **Changes to what a route accepts do not remove protections.** Never add `disable` entries while configuring. If a legitimate request is blocked, hand off to `barbacana-waf-tune`.

## Safety rules

- Relaxing limits (bigger bodies, more methods, wider `allow_origins`) is a security decision: say what the change allows in the report. Never use `*` as a CORS origin on a route that sends credentials; Barbacana rejects it, and the answer is a list of exact origins, not removing `allow_credentials` silently.
- Keep upload routes narrow (`match.paths` for the endpoint only), with `allowed_types` set. Do not raise `max_body_size` globally for one endpoint.
- Do not add a protection name you have not seen in `barbacana --catalog`. Do not edit `routes.d` files or any other team's routes without being asked.
- Rate limiting is configured with `rate_limit:` (`references/rate-limit.md`). A `header` source is only safe when the proxy in front sanitises that header; a client-controlled value lets an attacker rotate the key and bypass the limit. IP blocking and CAPTCHA are not part of Barbacana.

## References

| File | Read when |
|---|---|
| `references/routes-and-matching.md` | adding or reordering routes, path matching, hosts, `rewrite`, upstream URL and timeout |
| `references/limits-and-uploads.md` | body size, methods, content types, multipart uploads, JSON depth, and the status each limit returns |
| `references/cors-and-headers.md` | CORS, injected security headers, CSP, stripping response headers, custom block page |
| `references/openapi.md` | adding or changing `openapi.spec`, strictness, path vs rewrite, which violation returns which status |
| `references/rate-limit.md` | the user wants to throttle logins, an API key or a client, or asks about 429s |
| `references/routes-d.md` | the user asks for per-team files, `routes_dir` or `routes.d` |
| `references/validate-and-render.md` | `--validate` fails, or you need to read the render or choose where in the file to put a setting |
| `assets/*.yaml` | starting points; each validates under v0.10.x (`waf-openapi.yaml` needs its spec file present). Replace upstreams, paths and origins |

## Next step

Once the change is applied and tested, report it. If a legitimate request now gets 403, use `barbacana-waf-tune`. To watch blocked counts and logs use `barbacana-waf-operate`. For install, TLS or ports, use `barbacana-waf-install`.

## Found a problem?

Say where it belongs instead of working around it silently, and open an issue only if the user agrees. Remove hostnames, IPs, tokens and log contents from anything you post.

- Barbacana misbehaves (crash, wrong result, config that validates but fails to start): <https://github.com/barbacana-waf/barbacana/issues>
- The documentation is wrong or missing: <https://github.com/barbacana-waf/barbacana-docs/issues>
- This skill is wrong, unclear or missing a case: <https://github.com/barbacana-waf/skills/issues>
