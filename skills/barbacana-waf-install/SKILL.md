---
name: barbacana-waf-install
description: "Install, deploy and run the Barbacana WAF / API security gateway in front of a web app or API using Docker, Docker Compose, a binary, or Kubernetes/Helm. Use whenever the user wants to put a WAF in front of an app, protect an API, deploy or upgrade Barbacana, pick between auto-TLS and plain HTTP behind a load balancer, or verify a first run, even if they do not say 'install'."
---

# Barbacana: install and deploy

Gets a working Barbacana in front of the user's upstream and proves it with a smoke test.

## Ground rules (shared by all Barbacana skills)

- The CLI is flag-only: `barbacana --config <path> --validate`, `--render-config`, `--catalog`, `--catalog-leaf <id>`, `--version`. There are no subcommands.
- After every config edit, run `--validate` and fix what it reports before moving on.
- Use protection names exactly as `barbacana --catalog` prints them. Never invent names.
- Never show or suggest Caddy/Caddyfile syntax or CRS rule IDs. Protection names are the interface.
- Out of scope for Barbacana: rate limiting, IP blocking, CAPTCHA, TLS fingerprinting. Say so instead of improvising.

## Workflow

Propose each step and its exact commands, then run them once the user confirms. Never start containers or services unasked.

1. **Gather four facts.** Ask only for what you cannot infer from the project (compose files, Dockerfiles, existing configs):
   - the upstream: what address does the app listen on, and is it reachable from where Barbacana will run?
   - the target: Docker Compose, Kubernetes, or a bare binary with systemd
   - TLS: does Barbacana serve HTTPS itself (needs a public hostname, ports 80/443 open, DNS pointing here) or sit behind a load balancer/ingress that terminates TLS? Read `references/tls-modes.md`.
   - is this production? If so, pin the version, enable health and metrics ports, and offer signature verification.
2. **Pin a version.** Get the latest release (`gh release list -R barbacana-waf/barbacana --limit 1`, or the GitHub releases page) and use that tag. Do not use `:latest` outside throwaway tests, because it makes upgrades and rollbacks irreproducible.
3. **Write the config** from `assets/waf-http.yaml` (behind a load balancer) or `assets/waf-autotls.yaml` (auto-TLS). Keep it minimal: every protection is already on. Do not add `disable` entries during install.
4. **Validate before running.** `barbacana --config waf.yaml --validate` must print `config valid`. In a container: mount the file and run the image with `--config /etc/barbacana/waf.yaml --validate`. Fix errors using the message; they name the field.
5. **Write target files and start.** Follow the reference for the chosen target: `references/compose.md`, `references/kubernetes.md`, or `references/binary-systemd.md`.
6. **Smoke test.** See below. Report each result with its HTTP status.
7. **Offer verification** for production (`references/verify-and-upgrade.md`).
8. **Hand off.** Tell the user what is running, which ports are exposed, and which are internal-only.

## Smoke test

Run all three from where Barbacana is reachable:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://HOST:PORT/                       # expect the app's normal status
curl -s -w '\n%{http_code}\n' "http://HOST:PORT/?q=%27%20OR%201%3D1--"         # expect 403 {"error":"blocked",...}
curl -s -o /dev/null -w '%{http_code}\n' http://HOST:HEALTH_PORT/readyz          # expect 200, only if health_port is set
```

The second request is a harmless classic SQL-injection probe; a 403 proves the WAF is inspecting traffic. If it returns the app's normal status, Barbacana is not in the request path (wrong port, DNS, or the client is bypassing the proxy). Do not craft more aggressive payloads.

## Safety rules

- `metrics_port` and `health_port` are off by default. When enabled, keep them on an internal network: `/metrics` exposes route IDs and protection names. Never publish them on a public port or Service.
- Auto-TLS needs `data_dir` on a persistent volume, or certificates are re-requested on every restart and Let's Encrypt rate limits apply.
- Do not suggest rate limiting, IP blocking or CAPTCHA; Barbacana does not do those.
- Do not use edge images (`barbacana-edge`) in production; they are unsigned.

## References

| File | Read when |
|---|---|
| `references/tls-modes.md` | choosing between auto-TLS and plain HTTP, or `validate` reports a host/port conflict |
| `references/compose.md` | target is Docker Compose |
| `references/kubernetes.md` | target is Kubernetes |
| `references/binary-systemd.md` | target is a bare binary / systemd |
| `references/verify-and-upgrade.md` | production install, verifying signatures, upgrading, rolling back |

## Next step

Once the smoke test passes, use `barbacana-waf-configure` to add routes, headers, uploads and limits. If a legitimate request is blocked, use `barbacana-waf-tune`. To monitor the instance, use `barbacana-waf-operate`.
