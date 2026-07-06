# Storage

## ⚠️ Gotchas & Interactions

- **CNPG endpoint suffix:** The app database connection endpoint is always `{app}-cnpg-rw`. Never use `-ro` (read replica) or the bare cluster resource name for app connections.
- **openebs-hostpath is node-local:** Data is tied to the node. A pod rescheduling to a different node loses access to its PVC.

## Storage Classes

| Class              | Backend                                      | Use case                                                              |
| ------------------ | -------------------------------------------- | --------------------------------------------------------------------- |
| `ceph-ssd`         | Rook Ceph (default)                          | All persistent app workloads                                          |
| `openebs-hostpath` | Local node NVMe (`/var/mnt/local-hostpath`)  | CNPG, log DBs, actions-runner — node-local, no replication            |
| `local-hdd`        | Static PV, ai3090 HDD (`/var/mnt/local-hdd`) | ai3090-only bulk storage — comfyui workspace; no dynamic provisioning |
| `nfs-media`        | External NFS (TrueNAS)                       | Media library (Plex, \*arr stack)                                     |

## Kopiur (PVC Backup/Restore via Kopia)

Kopiur backs up PVCs via Kopia to a `ClusterRepository` on NFS (`clonenas.internal:/mnt/vault/backups/kubernetes/kopia`). Uses `kopiur.home-operations.com/v1alpha1` CRDs (SnapshotPolicy, SnapshotSchedule, Restore). rclone syncs the NFS repo to B2 separately. Add component `../../../../components/kopiur/backup` in `ks.yaml`.

### Required ks.yaml postBuild vars

```yaml
APP: *app               # always required
KOPIUR_CAPACITY: 5Gi    # PVC size (default 5Gi)
```

### Optional ks.yaml postBuild vars (with defaults)

| Var                    | Default              | Notes                  |
| ---------------------- | -------------------- | ---------------------- |
| `KOPIUR_ACCESSMODES`   | `ReadWriteOnce`      | PVC access mode        |
| `KOPIUR_CAPACITY`      | `5Gi`                | PVC size               |
| `KOPIUR_STORAGECLASS`  | `ceph-ssd`           | PVC storage class      |
| `KOPIUR_SNAPSHOTCLASS` | `csi-ceph-blockpool` | VolumeSnapshotClass    |
| `KOPIUR_CRON`          | `0 */4 * * *`        | Snapshot schedule cron |
| `KOPIUR_PUID`          | `1000`               | mover runAsUser        |
| `KOPIUR_PGID`          | `1000`               | mover runAsGroup       |

### Restore

Manually trigger a restore by editing the `Restore` CR (named `${APP}` in the app namespace) and setting its `spec.offset` to the desired number of snapshots back (0 = latest). The PVC will be re-populated via the CSI populator, then delete and recreate the pod to mount it.

## CNPG (PostgreSQL)

**Backups:** Two layers — pgdumps (via `cnpg` component CronJob) to NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/postgres`), and continuous WAL archival via barman-cloud to Backblaze B2.

Two clusters in the `database` namespace:

| Cluster            | Purpose                | PG Version         | Notes                                         |
| ------------------ | ---------------------- | ------------------ | --------------------------------------------- |
| `pgsql-cluster`    | All general apps       | PG17               | Default                                       |
| `pgvector-cluster` | Immich + pgvector apps | PG17 + vectorchord | Shared cluster for apps needing vector search |

**Connection endpoints:**

- Read-write: `${CNPG_NAME}-rw.database.svc.cluster.local:5432`
- Read-only: `${CNPG_NAME}-ro.database.svc.cluster.local:5432`

Secret keys (from component-generated ExternalSecret):

- `host`, `ro_host`, `user`, `password`, `db`, `uri`, `dsn`

### Add credentials for a new app

```bash
export APP=myapp
PASSWORD=$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 20)
akeyless update-secret-val \
  --name cnpg-users \
  --custom-field "${APP}_postgres_username=${APP}" \
  --custom-field "${APP}_postgres_password=${PASSWORD}"
```

### ks.yaml additions when using CNPG component

```yaml
components:
    - ../../../../components/cnpg

postBuild:
    substitute:
        CNPG_NAME: &postgresAppName pgsql-cluster # or pgvector-cluster

healthChecks:
    - apiVersion: &postgresVersion postgresql.cnpg.io/v1
      kind: &postgresKind Cluster
      name: *postgresAppName
      namespace: database
healthCheckExprs:
    - apiVersion: *postgresVersion
      kind: *postgresKind
      failed: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'False')
      current: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True')

dependsOn:
    - name: cnpg-cluster
      namespace: database
```
