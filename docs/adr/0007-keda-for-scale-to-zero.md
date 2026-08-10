# KEDA for scale-to-zero

**Status:** superseded by ADR-0010
**Date:** 2025-06-14
**Reconstructed:** from `c13968e9a` (2026-05-17), the commit that removed it

KEDA was adopted to scale NFS-dependent workloads to zero when their backing NAS was unavailable, using `ScaledObject` CRs with a Prometheus scaler per app.

## Consequences

- Required its own CRD release in bootstrap and a dedicated helper recipe in the just modules.
- Two near-duplicate scalers (`nfs-scaler`, `nfs-bkup-scaler`) existed only to distinguish the two NAS hosts — the duplication that native HPA plus a `job` label selector later removed.

> **Reconstructed record.** Written after the fact from the removal commit. The reasoning for _adopting_ KEDA in 2025 is not recorded anywhere — treat the "why" above as inference, not contemporaneous rationale.
