# Database

Namespace: `database`

| App      | Storage          | Notes                                    |
| -------- | ---------------- | ---------------------------------------- |
| cnpg     | openebs-hostpath | Two PostgreSQL clusters, Barman backups to B2 |
| dragonfly| —                | Redis-compatible in-memory cache         |
| pgadmin  | ceph-ssd         | Postgres for own config, volsync backup  |

## Config Notes

### CNPG (CloudNative-PG)

!!! warning "Two clusters — different images"

Two clusters with different images:

| Cluster       | Image                                | Use                              |
| ------------- | ------------------------------------ | -------------------------------- |
| pgsql-cluster | ghcr.io/cloudnative-pg/postgresql:17 | General apps                     |
| immich17      | ghcr.io/tensorchord/cloudnative-vectorchord:17 | Immich (vector search) |

Both use `openebs-hostpath` storage (local NVMe, no Ceph overhead for write-heavy DB workloads). Backups go to Backblaze B2 via Barman-cloud.

Read-write endpoint: `<cluster>-rw.database.svc.cluster.local`

Apps that need a database use the `cnpg` component in their `ks.yaml`, which creates a CronJob for DB user init and an ExternalSecret for credentials.

### Dragonfly

Redis-compatible cache at `dragonfly-cluster.database.svc.cluster.local:6379`:

| DB | Consumer |
| -- | -------- |
| 0  | Default  |
| 2  | Immich   |
| 3  | Searxng  |

### pgAdmin

Web UI for PostgreSQL management. Depends on both the CNPG cluster (to connect to) and volsync (for config backup).
