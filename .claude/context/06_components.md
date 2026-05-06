# Kustomize Components

Components live in `kubernetes/components/`. Add them to `ks.yaml` (not app `kustomization.yaml` unless noted).

## volsync — PVC backup to Backblaze B2

```yaml
# ks.yaml
components:
  - ../../../../components/volsync
postBuild:
  substitute:
    APP: *app
    VOLSYNC_CAPACITY: 5Gi   # required; see 04_storage.md for optional vars
dependsOn:
  - name: rook-ceph-cluster
    namespace: rook-ceph
  - name: volsync
    namespace: volsync-system
```

See `04_storage.md` for all VolSync vars and restore command.

## cnpg — PostgreSQL user secret + init cronjob

```yaml
# ks.yaml
components:
  - ../../../../components/cnpg
postBuild:
  substitute:
    APP: *app
    CNPG_NAME: &postgresAppName pgsql-cluster   # or immich17
healthChecks: [...]       # see 04_storage.md for full block
dependsOn:
  - name: cnpg-cluster
    namespace: database
```

Creates: `${APP}-pguser-secret` (host, port, user, password, db, uri, dsn) + a CronJob for DB init.

## ext-auth-internal — SSO for internal apps

Add to the **app's `kustomization.yaml`** (not `ks.yaml`):
```yaml
# kubernetes/apps/{ns}/{app}/app/kustomization.yaml
components:
  - ../../../../components/ext-auth-internal
```

Creates a `SecurityPolicy` targeting the HTTPRoute named `${APP}`. Override with `EXT_AUTH_TARGET: custom-name` in `postBuild.substitute` if route name differs.

## ext-auth-external — SSO for external apps

Same as above but for `envoy-external` gateway:
```yaml
components:
  - ../../../../components/ext-auth-external
```

## keda/nfs-scaler — scale-to-zero when NFS (unraid) is unreachable

```yaml
# ks.yaml
components:
  - ../../../../components/keda/nfs-scaler
dependsOn:
  - name: keda
    namespace: observability
```

Scales deployment to 0 when `unraid.internal:2049` is unreachable (Prometheus probe). Restores original replicas when reachable.

## keda/nfs-bkup-scaler — same but for TrueNAS backup NFS

```yaml
components:
  - ../../../../components/keda/nfs-bkup-scaler
```

Probes `truenas.internal:2049`.

## common — Flux alerts + GitHub status notifications

Add to any namespace's `kustomization.yaml` for Flux alerting:
```yaml
components:
  - ../../../components/common
```

Includes: Alertmanager provider, GitHub commit-status provider. Rarely needs to be added manually — already wired at the namespace level.
