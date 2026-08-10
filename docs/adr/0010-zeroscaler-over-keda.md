# zeroscaler (native HPA + prometheus-adapter) over KEDA

**Status:** accepted
**Date:** 2026-05-17
**Supersedes:** ADR-0007

KEDA was replaced with a generic `zeroscaler` Kustomize component driving a **native** HorizontalPodAutoscaler against the `probe_success` metric, served through `prometheus-adapter`'s external metrics API. This removed an operator, its CRDs and its bootstrap release in exchange for a component that any app can add in one line.

## Consequences

- The two KEDA scalers collapsed into one component parameterised by `ZEROSCALER_JOB_NAME`, selecting between the `nfs_probe` (truenas) and `nfs_bkup_probe` (clonenas) blackbox probes.
- **Adding the component is not sufficient** — the app also needs a matching entry in the `prometheus-adapter` ConfigMap. Without it the HPA reports `TARGETS: <unknown>/1` and silently never scales.
- No `dependsOn` on observability is declared: if the metrics API is unavailable the HPA holds replicas rather than failing reconciliation, which is the desired degradation.
- `prometheus-adapter` registers the `custom.metrics.k8s.io` APIService — only one component may hold it at a time.
