# TLS and deployment modes

Exactly one mode applies, chosen by `host`, `port` and route-level `match.hosts`.

| Mode | Config | Use when | Ports |
|---|---|---|---|
| 1. Single or list of hosts, auto-TLS | top-level `host: api.example.com` (or a list) | Barbacana is the public edge | 80 (redirects) and 443 |
| 2. Multi-host, auto-TLS | no `host`; every route has `match.hosts` | different hostnames go to different upstreams | 80 and 443 |
| 3. Plain HTTP | `port: 8080` (default when nothing else is set) | behind a load balancer or ingress that terminates TLS | the chosen port |

Rules the validator enforces (errors are hard failures):
- `host` and `port` are mutually exclusive.
- `host` and route `match.hosts` are mutually exclusive.
- If any route has `match.hosts`, every route must.
- `port`, `metrics_port` and `health_port` must differ when non-zero.

Auto-TLS requirements: the hostname resolves to this machine, ports 80 and 443 are reachable from the internet, and `data_dir` (default `/data/barbacana`) is a persistent, writable volume.

Default to Mode 3 on Kubernetes and any platform with a managed load balancer. Choose Mode 1 for a single VM or homelab host with a public name.

`metrics_port` and `health_port` default to `0` (listener not started). Set them explicitly for production: for example 9090 and 8081.
