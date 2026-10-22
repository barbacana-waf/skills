# Docker Compose

Start from `assets/compose.yaml` and `assets/waf-autotls.yaml` (or `waf-http.yaml`).

1. Put `waf.yaml` next to the compose file; mount it read-only at `/etc/barbacana/waf.yaml`.
2. Mount a named volume at `/data/barbacana`.
3. Publish `80:80` and `443:443` for auto-TLS, or only the plain port (for example `8080:8080`) for Mode 3. Do not publish the metrics or health ports to the host unless the host network is trusted.
4. Reach the app by its compose service name in `upstream`, for example `http://app:8000`. The app should use `expose`, not `ports`, so it is only reachable through Barbacana.
5. Validate first: `docker compose run --rm barbacana --config /etc/barbacana/waf.yaml --validate` (the image entrypoint already runs the server, so pass flags only).
6. `docker compose up -d`, then `docker compose logs barbacana`. Audit events are JSON on stdout.

The image runs as a non-root user. If a bind-mounted data directory is used instead of a named volume, it must be writable by that user.
