# CloudNativePG for PostgreSQL

**Status:** accepted
**Date:** 2025-04-21

Apps needing Postgres get it from a shared CloudNativePG cluster in the `database` namespace rather than a per-app database container, so backup, WAL archival, failover and version upgrades are solved once instead of per app.

## Consequences

- Apps connect through the `-rw` endpoint. The `-ro` endpoint is a read replica and the bare cluster resource name is not a connection target — using either is a recurring source of app-level breakage.
- Credentials are provisioned by the `cnpg` component, which creates both a Secret and an init CronJob in the app's namespace. The password is **not** generated — it must be written to aKeyless first, as fields on the shared `cnpg-users` secret (`${APP}_postgres_username` / `${APP}_postgres_password`); the component only reads it. Skipping this step yields an app that reconciles and then fails to connect. See `kubernetes/components/cnpg/README.md`.
- Backups run in two layers: pgdumps to NFS on `clonenas`, and continuous WAL archival to Backblaze B2 via barman-cloud.
- The cluster runs on `openebs-hostpath`, not Ceph — database replication is CNPG's job, and layering it over Ceph replication costs write latency for no additional durability.
