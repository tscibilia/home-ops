# Kustomize Components

## ⚠️ Gotchas & Interactions

- **zeroscaler requires a prometheus-adapter metric:** Adding the `zeroscaler` component to `ks.yaml` is not enough — the app also needs a custom metric entry in the `prometheus-adapter` ConfigMap. Component without metric = scaling never triggers, silently.
- **cnpg creates a CronJob:** The `cnpg` component creates a Secret AND an init CronJob in the app's namespace. Verify the namespace before applying.
- **Update 02_apps_inventory.md:** When adding or removing a component from an app, update the app's entry in `02_apps_inventory.md`.

Components live in `kubernetes/components/`. Add them to `spec.components` in the Flux Kustomization (`ks.yaml`). All components — including `auth` — go in ks.yaml, never in the app's `kustomization.yaml`.

Available: `alerts/`, `auth/`, `cnpg/`, `kopiur/{backup,secret}`, `secrets/`, `zeroscaler/`.

## kopiur — PVC backup to NFS (clonenas) via Kopia

Replaces VolSync. Uses `kopiur.home-operations.com` CRDs (SnapshotPolicy, SnapshotSchedule, Restore) with a `ClusterRepository` pointing to NFS on `clonenas.internal`.

```yaml
# ks.yaml
components:
    - ../../../../components/kopiur/backup
postBuild:
    substitute:
        APP: *app
        KOPIUR_CAPACITY: 5Gi # optional; see 04_storage.md for full var table
dependsOn:
    - name: secret-stores
      namespace: external-secrets
    - name: kopiur
      namespace: kopiur-system
```

A separate `kopiur/secret` component distributes the `kopiur-nas-secret` (Kopia repo password from aKeyless `/kubernetes/kopiur`) per namespace — not added per-app; the cluster-level setup handles it.

See `04_storage.md` for all Kopiur vars and restore command.

## cnpg — PostgreSQL user secret + init cronjob

```yaml
# ks.yaml
components:
    - ../../../../components/cnpg
postBuild:
    substitute:
        APP: *app
        CNPG_NAME: &postgresAppName pgsql-cluster # or immich17
healthChecks: [...] # see 04_storage.md for full block
dependsOn:
    - name: cnpg-cluster
      namespace: database
```

Creates: `${APP}-pguser-secret` (host, port, user, password, db, uri, dsn) + a CronJob for DB init.

## auth — tinyauth forward auth

One component for **both** gateways — there is no internal/external split. Add to the **Flux Kustomization (`ks.yaml`)** `spec.components` (not the app's `kustomization.yaml`):

```yaml
# kubernetes/apps/{ns}/{app}/ks.yaml
spec:
    components:
        - ../../../../components/auth
```

Creates a `SecurityPolicy` routing ext-auth to `tinyauth.security:3000`, targeting the HTTPRoute named `${APP}`.

**Substitution variables:**

| Var                  | Default                     | Purpose                      |
| -------------------- | --------------------------- | ---------------------------- |
| `${EXT_AUTH_TARGET}` | `${APP}`                    | Name of the targeted route   |
| `${EXT_AUTH_KIND}`   | `HTTPRoute`                 | Target kind (e.g. `Gateway`) |
| `${EXT_AUTH_GROUP}`  | `gateway.networking.k8s.io` | Target API group             |

Use this **only** for apps that cannot do OIDC themselves. Apps with native OIDC get a `PocketIDOIDCClient` CR instead and no component — see `03_networking.md`. Never apply both to one app.

Forward-auth apps also need the Gatus route/service annotation swap — see `03_networking.md`.

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

For clonenas-backed apps (kopiur, rclone), override the probe job:

```yaml
postBuild:
    substitute:
        APP: *app
        ZEROSCALER_JOB_NAME: nfs_bkup_probe
```

No `dependsOn` on observability — the HPA uses the external metrics API served by `prometheus-adapter` (in `observability` namespace). If the API isn't available, HPA shows `TARGETS: <unknown>/1` and holds replicas — no scaling decisions made.

**Substitution variables:**

| Var                         | Default         | Purpose                            |
| --------------------------- | --------------- | ---------------------------------- |
| `${APP}`                    | (required)      | Target Deployment/StatefulSet name |
| `${CONTROLLER}`             | `Deployment`    | Workload kind                      |
| `${ZEROSCALER_METRIC_NAME}` | `probe_success` | External metric name from adapter  |
| `${ZEROSCALER_JOB_NAME}`    | `nfs_probe`     | `job` label selector value         |

**Behavior:** `stabilizationWindowSeconds: 0` on both scaleDown/scaleUp; `periodSeconds: 15`. Workload reacts within ~15 s of probe state change.

**Prerequisites:**

- `prometheus-adapter` deployed in `observability` (kustomization auto-applies on cluster bootstrap)
- A Prometheus `Probe` CR with `spec.jobName` matching `${ZEROSCALER_JOB_NAME}`. Current Probes (in `apps/observability/exporters/blackbox-exporter/app/probes.yaml`):
    - `nfs` → `jobName: nfs_probe` → `truenas.internal:2049`
    - `nfs-bkup` → `jobName: nfs_bkup_probe` → `clonenas.internal:2049`

For a custom HPA targeting a different deployment in the same app (e.g., immich's `immich-server`), don't use the component — add an explicit `horizontalpodautoscaler.yaml` in `app/` with the same `probe_success` + `job: nfs_probe` selector pattern.
