# Kustomize Components

## ⚠️ Gotchas & Interactions

- **zeroscaler requires a prometheus-adapter metric:** Adding the `zeroscaler` component to `ks.yaml` is not enough — the app also needs a custom metric entry in the `prometheus-adapter` ConfigMap. Component without metric = scaling never triggers, silently.
- **cnpg creates a CronJob:** The `cnpg` component creates a Secret AND an init CronJob in the app's namespace. Verify the namespace before applying.
- **Update 02_apps_inventory.md:** When adding or removing a component from an app, update the app's entry in `02_apps_inventory.md`.

Components live in `kubernetes/components/`. Add them to `spec.components` in the Flux Kustomization (`ks.yaml`). All components — including ext-auth — go in ks.yaml, never in the app's `kustomization.yaml`.

## volsync — PVC backup to NFS (clonenas)

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

NFS injection is explicit via `moverVolumes` in the component spec — no MutatingAdmissionPolicy needed.

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

Add to the **Flux Kustomization (`ks.yaml`)** `spec.components` (not the app's `kustomization.yaml`):

```yaml
# kubernetes/apps/{ns}/{app}/ks.yaml
spec:
    components:
        - ../../../../components/ext-auth-internal
```

Creates a `SecurityPolicy` targeting the HTTPRoute named `${APP}`. Override with `EXT_AUTH_TARGET: custom-name` in `postBuild.substitute` if route name differs.

## ext-auth-external — SSO for external apps

Same as above but for `envoy-external` gateway:

```yaml
spec:
    components:
        - ../../../../components/ext-auth-external
```

## zeroscaler — scale-to-zero via native HPA + prometheus-adapter

Generic HPA component driven by Prometheus `probe_success` metric. Replaced `keda/nfs-scaler` + `keda/nfs-bkup-scaler` (2026-05-17).

```yaml
# ks.yaml — defaults to truenas (job: nfs_probe)
components:
  - ../../../../components/zeroscaler
postBuild:
  substitute:
    APP: *app
```

For clonenas-backed apps (volsync, rclone), override the probe job:

```yaml
postBuild:
  substitute:
    APP: *app
    ZEROSCALER_JOB_NAME: nfs_bkup_probe
```

No `dependsOn` on observability — the HPA uses the external metrics API served by `prometheus-adapter` (in `observability` namespace). If the API isn't available, HPA shows `TARGETS: <unknown>/1` and holds replicas — no scaling decisions made.

**Substitution variables:**
| Var | Default | Purpose |
|---|---|---|
| `${APP}` | (required) | Target Deployment/StatefulSet name |
| `${CONTROLLER}` | `Deployment` | Workload kind |
| `${ZEROSCALER_METRIC_NAME}` | `probe_success` | External metric name from adapter |
| `${ZEROSCALER_JOB_NAME}` | `nfs_probe` | `job` label selector value |

**Behavior:** `stabilizationWindowSeconds: 0` on both scaleDown/scaleUp; `periodSeconds: 15`. Workload reacts within ~15 s of probe state change.

**Prerequisites:**

- `prometheus-adapter` deployed in `observability` (kustomization auto-applies on cluster bootstrap)
- A Prometheus `Probe` CR with `spec.jobName` matching `${ZEROSCALER_JOB_NAME}`. Current Probes (in `apps/observability/exporters/blackbox-exporter/app/probes.yaml`):
    - `nfs` → `jobName: nfs_probe` → `truenas.internal:2049`
    - `nfs-bkup` → `jobName: nfs_bkup_probe` → `clonenas.internal:2049`

For a custom HPA targeting a different deployment in the same app (e.g., immich's `immich-server`), don't use the component — add an explicit `horizontalpodautoscaler.yaml` in `app/` with the same `probe_success` + `job: nfs_probe` selector pattern.
