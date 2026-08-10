# kopiur over VolSync for PVC backup

**Status:** accepted
**Date:** 2026-07-05
**Supersedes:** ADR-0005

PVC backup moved from VolSync/restic to kopiur, which uses Kopia against a `ClusterRepository` on NFS (`clonenas.internal:/mnt/vault/backups/kubernetes/kopia`). Restore became an in-place operation — edit the `Restore` CR's `spec.offset` — instead of provisioning a replacement PVC and repointing the app.

## Consequences

- Apps opt in with the `components/kopiur/backup` component plus `KOPIUR_*` substitutions; a separate `kopiur/secret` component distributes the repository password per namespace and is handled at cluster level, not per app.
- Restore procedure: set `spec.offset` on the `Restore` CR (`0` = latest), let the CSI populator repopulate the PVC, then delete and recreate the pod to remount it.
- Off-site copies are a separate concern — rclone syncs the NFS repository to Backblaze B2 on its own schedule rather than each app backing up twice.
- Adding kopiur requires `dependsOn` on both `secret-stores` and `kopiur`.
