# Storage

## ⚠️ Gotchas & Interactions

- **CNPG endpoints are named after the cluster, not the app:** the `host` key is `{cluster}-rw.database.svc.cluster.local` — `pgsql-cluster-rw` or `pgvector-cluster-rw`, shared by every app on that cluster. Use the `host` key from `${APP}-pguser-secret` rather than composing a name. Never point an app at `-ro`; that is the read replica.
- **openebs-hostpath is node-local:** Data is tied to the node. A pod rescheduling to a different node loses access to its PVC.

## Storage Classes

| Class              | Backend                                      | Use case                                                              |
| ------------------ | -------------------------------------------- | --------------------------------------------------------------------- |
| `ceph-ssd`         | Rook Ceph (default)                          | All persistent app workloads                                          |
| `openebs-hostpath` | Local node NVMe (`/var/mnt/local-hostpath`)  | CNPG, log DBs, actions-runner — node-local, no replication            |
| `local-hdd`        | Static PV, ai3090 HDD (`/var/mnt/local-hdd`) | ai3090-only bulk storage — comfyui workspace; no dynamic provisioning |
| `nfs-media`        | External NFS (TrueNAS)                       | Media library (Plex, \*arr stack)                                     |

## Kopiur (PVC Backup/Restore via Kopia)

Kopiur backs up PVCs via Kopia to a `ClusterRepository` on NFS (`clonenas.internal:/mnt/vault/backups/kubernetes/kopia`). Uses `kopiur.home-operations.com/v1alpha1` CRDs (SnapshotPolicy, SnapshotSchedule, Restore). rclone syncs the NFS repo to B2 separately. ([ADR-0013](../adr/0013-kopiur-over-volsync.md))

Backing up an app's PVC, the substitution vars, and the restore procedure are all in `06_components.md` → `kopiur/backup`.

## CNPG (PostgreSQL)

**Backups:** Two layers — pgdumps (via `cnpg` component CronJob) to NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/postgres`), and continuous WAL archival via barman-cloud to Backblaze B2.

Two clusters in the `database` namespace ([ADR-0004](../adr/0004-cloudnativepg-for-postgresql.md), [ADR-0011](../adr/0011-pgvector-cluster-split.md)):

| Cluster            | Purpose                | PG Version         | Notes                                         |
| ------------------ | ---------------------- | ------------------ | --------------------------------------------- |
| `pgsql-cluster`    | All general apps       | PG17               | Default                                       |
| `pgvector-cluster` | Immich + pgvector apps | PG17 + vectorchord | Shared cluster for apps needing vector search |

**Connection endpoints:**

- Read-write: `${CNPG_NAME}-rw.database.svc.cluster.local:5432`
- Read-only: `${CNPG_NAME}-ro.database.svc.cluster.local:5432`

Secret keys (from component-generated ExternalSecret):

- `host`, `ro_host`, `port`, `user`, `password`, `db`, `uri`, `dsn`

Connecting an app to one of these clusters — the `ks.yaml` stanza, the health checks, and the aKeyless credential the component expects — is in `06_components.md` → `cnpg`.
