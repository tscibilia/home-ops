# Storage

## ⚠️ Gotchas & Interactions

- **CNPG endpoints are named after the cluster, not the app:** the `host` key is `{cluster}-rw.database.svc.cluster.local` — `pgcluster-default-rw` or `pgcluster-vector-rw`, shared by every app on that cluster. Use the `host` key from `${APP}-pguser-secret` rather than composing a name. Never point an app at `-ro`; that is the read replica.
- **Ceph mutes four `AUTH_INSECURE_*` warnings on purpose:** Ceph Tentacle (v20) flags the older `aes` cephx cipher. Daemon keys (mon/mgr/osd) are rotated to `aes256k` via `security.cephx.daemon`, but CSI keys are pinned to `aes` because `aes256k` needs a host kernel of 7.0+ and the Talos nodes are below that. The remaining warnings cannot clear, so they are muted declaratively in `cephClusterSpec.healthCheck.muteHealthWarning`. Unmute — and drop `security.cephx.csi.keyType` — once the nodes reach kernel 7.0+.
- **openebs-hostpath is node-local:** Data is tied to the node. A pod rescheduling to a different node loses access to its PVC.

## Storage Classes

| Class              | Backend                                                              | Use case                                                              |
| ------------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `ceph-ssd`         | Rook Ceph (default)                                                  | All persistent app workloads                                          |
| `openebs-hostpath` | Local node NVMe (`/var/mnt/local-hostpath`)                          | CNPG, log DBs, actions-runner — node-local, no replication            |
| `local-hdd`        | Static PV, ai3090 HDD (`/var/mnt/local-hdd`)                         | ai3090-only bulk storage — comfyui workspace; no dynamic provisioning |
| `nfs-share`        | External NFS via csi-driver-nfs (TrueNAS `/mnt/nas/data/shares/k8s`) | General shared storage between apps                                   |

The media library is **not** a storage class. Media apps mount it directly as a `type: nfs` volume in the HelmRelease — `server: truenas.internal`, `path: /mnt/nas/data/media` — with no PVC involved.

## Kopiur (PVC Backup/Restore via Kopia)

Kopiur backs up PVCs via Kopia to a `ClusterRepository` on NFS (`clonenas.internal:/mnt/vault/backups/kubernetes/kopia`). Uses `kopiur.home-operations.com/v1alpha1` CRDs (SnapshotPolicy, SnapshotSchedule, Restore). rclone syncs the NFS repo to B2 separately. ([ADR-0013](../adr/0013-kopiur-over-volsync.md))

Backing up an app's PVC, the substitution vars, and the restore procedure are all in `components.md` → `kopiur/backup`.

## CNPG (PostgreSQL)

**Backups:** layered — pgdumps (via `cnpg` component CronJob) to NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/postgres`), and continuous WAL archival via barman-cloud to Backblaze B2.

Clusters in the `database` namespace ([ADR-0004](../adr/0004-cloudnativepg-for-postgresql.md), [ADR-0011](../adr/0011-pgvector-cluster-split.md)):

| Cluster               | Purpose                | Notes                                                            |
| --------------------- | ---------------------- | ---------------------------------------------------------------- |
| `pgcluster-default`   | All general apps       | Default                                                          |
| `pgcluster-vector`    | Immich + pgvector apps | Shared cluster for apps needing vector search; adds vectorchord  |
| `pgcluster-timescale` | tracearr               | Time-series; built from an `ImageCatalog`, not a plain image tag |

`pgsql-cluster` and `pgvector-cluster` are the pre-rename names of the first two.
They are still on disk as warm rollback copies and are deleted once the new
clusters have soaked ([ADR-0021](../adr/0021-blue-green-rename-then-in-place-major-upgrade.md)).

<!-- verify-ignore: cnpg-undocumented pgsql-cluster -->
<!-- verify-ignore: cnpg-undocumented pgvector-cluster -->

The PostgreSQL major version is not recorded here — it is whatever `imageName`
says in each cluster's manifest under `kubernetes/apps/database/cnpg/`. Renovate
bumps that, so a version written here would be stale the day it changes.

**Connection endpoints:**

- Read-write: `${CNPG_NAME}-rw.database.svc.cluster.local:5432`
- Read-only: `${CNPG_NAME}-ro.database.svc.cluster.local:5432`

Secret keys (from component-generated ExternalSecret):

- `host`, `ro_host`, `port`, `user`, `password`, `db`, `uri`, `dsn`

Connecting an app to one of these clusters — the `ks.yaml` stanza, the health checks, and the aKeyless credential the component expects — is in `components.md` → `cnpg`.
