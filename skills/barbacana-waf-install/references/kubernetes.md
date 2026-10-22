# Kubernetes

`assets/kubernetes.yaml` is a plain ConfigMap + Deployment + Service for Mode 3 (TLS terminated by the ingress). Replace `vX.Y.Z` and the upstream service address.

- Probes: liveness `/healthz`, readiness `/readyz`, both on `health_port` (8081). They only exist when `health_port` is set in the config.
- Config: mounted from the ConfigMap at `/etc/barbacana/`. Config changes need a rollout (`kubectl rollout restart deployment/barbacana`), because the file is read at start.
- `data_dir` must be writable, so the sample mounts an `emptyDir`. Use a PersistentVolumeClaim only for auto-TLS (Mode 1) with a single replica.
- Do not expose the `metrics` and `health` ports through the Service or Ingress. Scrape metrics from inside the cluster.
- Validate before applying: `kubectl create configmap` is not needed; run `barbacana --config waf.yaml --validate` locally or in a throwaway pod.
- The chart in `deploy/helm` of the main repo is incomplete (values only). Do not promise Helm. Prefer these manifests.

These manifests have been checked for YAML correctness but not applied to a cluster in this repo's tests. Say so if the user asks, and watch the first rollout.
