# Storage

## ⚠️ Gotchas & Interactions

- **CNPG endpoint suffix:** The app database connection endpoint is always `{app}-cnpg-rw`. Never use `-ro` (read replica) or the bare cluster resource name for app connections.
- **VolSync NFS securityContext:** ALL VolSync NFS job templates require an explicit `securityContext`, including `list.yaml.j2`. Omitting it causes silent permission failures — the job runs but cannot access the NFS share.
- **openebs-hostpath is node-local:** Data is tied to the node. A pod rescheduling to a different node loses access to its PVC.

## Storage Classes

| Class | Backend | Use case |
|-------|---------|----------|
| `ceph-ssd` | Rook Ceph (default) | All persistent app workloads |
| `openebs-hostpath` | Local node | CNPG, log DBs, actions-runner — node-local, no replication |
| `nfs-media` | External NFS (TrueNAS) | Media library (Plex, *arr stack) |

## VolSync (PVC Backup/Restore)

VolSync backs up PVCs via Restic to an NFS share on `clonenas.internal` (`/mnt/vault/backups/kubernetes/volsync`), injected by a MutatingAdmissionPolicy. rclone syncs the NFS repo to B2 separately. Add component `../../../../components/volsync` in `ks.yaml`.

### Required ks.yaml postBuild vars
```yaml
APP: *app              # always required
VOLSYNC_CAPACITY: 5Gi  # PVC size
```

### Optional ks.yaml postBuild vars (with defaults)
| Var | Default | Notes |
|-----|---------|-------|
| `VOLSYNC_CLAIM` | `${APP}` | PVC name if different from app name |
| `VOLSYNC_SCHEDULE` | `0 */6 * * *` | Backup cron schedule |
| `VOLSYNC_STORAGECLASS` | `ceph-ssd` | PVC storage class |
| `VOLSYNC_SNAPSHOTCLASS` | `csi-ceph-blockpool` | Volume snapshot class |
| `VOLSYNC_ACCESSMODES` | `ReadWriteOnce` | |
| `VOLSYNC_CACHE_CAPACITY` | `1Gi` | Restic cache PVC size |
| `VOLSYNC_CACHE_SNAPSHOTCLASS` | `openebs-hostpath` | Cache storage class |
| `VOLSYNC_PUID` | `1000` | mover runAsUser |
| `VOLSYNC_PGID` | `1000` | mover runAsGroup/fsGroup |
| `VOLSYNC_COPYMETHOD` | `Snapshot` | Use `Clone` for CephFS |

### Restore
```bash
just kube volsync-restore <namespace> <app> <previous>
```
`<previous>` is a Restic snapshot ID or `r:latest`.

## CNPG (PostgreSQL)

**Backups:** Two layers — pgdumps (via `cnpg` component CronJob) to NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/postgres`), and continuous WAL archival via barman-cloud to Backblaze B2.

Two clusters in the `database` namespace:

| Cluster | Purpose | PG Version | Notes |
|---------|---------|------------|-------|
| `pgsql-cluster` | All general apps | PG17 | Default |
| `immich17` | Immich only | PG17 + vectorchord | pgvector extension |

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
    CNPG_NAME: &postgresAppName pgsql-cluster  # or immich17

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
