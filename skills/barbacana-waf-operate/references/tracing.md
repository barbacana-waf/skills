# OpenTelemetry tracing (checked on v0.9.7, not re-tested on v0.10.0)

Off by default. When off, no exporter is created and requests pay nothing.

```yaml
tracing:
  enabled: true
  protocol: grpc            # or http (== http/protobuf)
  endpoint: otel-collector:4317
  insecure: true            # default true; false requires TLS to the collector
  headers: {}               # auth headers; keep real values out of git
  timeout: 5s               # optional, >= 100ms
  service: {name: barbacana, namespace: "", version: ""}
```

`assets/waf-observability.yaml` has a validated example. Defaults of an omitted `endpoint` come from the standard `OTEL_EXPORTER_OTLP_ENDPOINT` variable; the service name is `tracing.service.name`, else `barbacana` (`OTEL_SERVICE_NAME` is not read; set the YAML field). The `tracing` block is read **at startup only**: apply changes with a restart. The default gRPC port is 4317, HTTP 4318 (with `protocol: http` the endpoint is a host:port or URL as your collector expects).

## What you get

A server span `barbacana.evaluate` per request (attributes: method, path, host), a child `waf.evaluate` with one `waf.stage.<name>` span per pipeline stage, and `waf.upstream` for the proxy call. Block or match decisions set `waf.action` (`block` or `log`), `waf.protection`/`waf.protections`, and the CRS stage records `waf.score`. Barbacana extracts an incoming W3C `traceparent` and passes it on to the upstream, so traces continue through it.

## Verify

1. Start with the block and confirm the logs show `barbacana started` with no exporter error. An unreachable collector does **not** stop startup or requests; spans are simply dropped, so check the collector, not Barbacana.
2. Send a request with a known id (dev/staging only): `curl -H 'traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01' …` and look for that trace id in the backend.
3. With tracing enabled, blocked and detected audit events carry the trace and span id: `metadata.trace_id` and `metadata.span_id` in OCSF, `trace.id` and `span.id` in ECS (confirmed on both: an incoming `traceparent` shows up in the event). Pivot from a `request_id` in the log to the trace with that id.

On shutdown Barbacana waits up to 5s to flush spans.
