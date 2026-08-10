# VolSync for PVC backup

**Status:** superseded by ADR-0013
**Date:** 2025-04-23
**Reconstructed:** from `574a0c0e2` (2026-07-05), the commit that removed it

VolSync was adopted to back up PVCs to NFS on `clonenas` using restic, driven by per-app `ReplicationSource` / `ReplicationDestination` CRs with a mover pod per app.

## Consequences

- Restore was a two-CR dance — create a `ReplicationDestination`, wait for it to populate a new PVC, then repoint the app — which made restores rare and error-prone enough to motivate the move to kopiur.
- Left behind `AWS_VOLSYNC_BUCKET` in `cluster-secrets` and `volsync-*` recipes in the just modules, both removed later.

> **Reconstructed record.** Written after the fact from the removal commit. The reasoning for _adopting_ VolSync in 2025 is not recorded anywhere and is not reproduced here — treat the "why" above as inference from its shape, not as contemporaneous rationale.
