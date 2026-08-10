# Kustomize Components

## ⚠️ Gotchas & Interactions

- **zeroscaler requires a prometheus-adapter metric:** Adding the `zeroscaler` component to `ks.yaml` is not enough — the app also needs a custom metric entry in the `prometheus-adapter` ConfigMap. Component without metric = scaling never triggers, silently.
- **cnpg creates a CronJob:** The `cnpg` component creates a Secret AND an init CronJob in the app's namespace. Verify the namespace before applying.
- **Update 02_apps_inventory.md:** When adding or removing an app component, update the app's entry in `02_apps_inventory.md`.
- **Placement is not interchangeable:** An app component in a namespace `kustomization.yaml` applies to every app in the namespace; a namespace component in a `ks.yaml` is missing the substitutions it never had. Check which kind you are adding before you add it.

Components live in `kubernetes/components/`. They come in two kinds, and the difference is where they are declared:

| Kind                    | Declared in                               | Configured by             | Components                                                   |
| ----------------------- | ----------------------------------------- | ------------------------- | ------------------------------------------------------------ |
| **app component**       | `ks.yaml` → `spec.components`             | `postBuild.substitute`    | `auth`, `cnpg`, `kopiur/backup`, `zeroscaler`                |
| **namespace component** | `kubernetes/apps/{ns}/kustomization.yaml` | nothing — no per-app vars | `alerts`, `alerts/github-status`, `secrets`, `kopiur/secret` |

Neither kind ever goes in an app's own `app/kustomization.yaml`.

## App components

### kopiur/backup — PVC backup to NFS (clonenas) via Kopia

Uses `kopiur.home-operations.com` CRDs (SnapshotPolicy, SnapshotSchedule, Restore) with a `ClusterRepository` pointing to NFS on `clonenas.internal`. ([ADR-0013](../adr/0013-kopiur-over-volsync.md))

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

The repository password comes from the `kopiur/secret` namespace component — see below. Do not add it per app.

See `04_storage.md` for all Kopiur vars and restore command.

### cnpg — PostgreSQL user secret + init cronjob

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

### auth — tinyauth forward auth

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

Use this **only** for apps that cannot do OIDC themselves. Apps with native OIDC get a `PocketIDOIDCClient` CR instead and no component — see `03_networking.md`. Never apply both to one app. ([ADR-0014](../adr/0014-pocket-id-tinyauth-over-authentik.md))

Forward-auth apps also need the Gatus route/service annotation swap — see `03_networking.md`.

### zeroscaler — scale-to-zero via native HPA + prometheus-adapter

Generic HPA component driven by Prometheus `probe_success` metric. ([ADR-0010](../adr/0010-zeroscaler-over-keda.md))

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

## Namespace components

Declared once per namespace, alongside the `resources:` list of `ks.yaml` paths. They take no substitutions and never appear in a `ks.yaml`.

```yaml
# kubernetes/apps/{namespace}/kustomization.yaml
components:
    - ../../components/alerts
    - ../../components/secrets
    - ../../components/kopiur/secret # only where the namespace has kopiur-backed apps
```

**Creating a new namespace:** `alerts` and `secrets` are not optional — every namespace has both. Omitting `secrets` is the usual cause of `${SECRET_DOMAIN}` failing to substitute for a new app.

### alerts — Flux failure notifications

All 17 namespaces. Creates a Flux `Provider` pointing at `alertmanager-operated.observability.svc.cluster.local:9093` and an `Alert` at `eventSeverity: error` covering every Flux kind (FluxInstance, GitRepository, HelmRelease, HelmRepository, Kustomization, OCIRepository). Carries an `exclusionList` for known-noisy errors (GitHub lookup failures, TCP dial timeouts, socket waits).

### alerts/github-status — commit status notifications

`flux-system` only, and added as its own entry — it is deliberately commented out of the parent `alerts` component because it hit GitHub secondary rate limits when applied namespace-wide.

### secrets — the cluster-secrets Secret

All 17 namespaces. Creates the `cluster-secrets` ExternalSecret, which is what makes `substituteFrom: cluster-secrets` resolve in that namespace. Keys: `SECRET_DOMAIN`, `CEAPP_DOMAIN`, `TIMEZONE`, `TAILSCALE_MAGICDNS`, `KOPIA_BUCKET`, drawn from three aKeyless paths (`/kubernetes/cluster-secrets`, `/network/tailscale/operator`, `/cloud-providers/b2-creds`). See `05_secrets.md`.

### kopiur/secret — the Kopia repository password

Namespaces with kopiur-backed apps only: `ai`, `database`, `default`, `home-automation`, `kopiur-system`, `media`, `observability`, `security`. Creates `kopiur-nas-secret` (`KOPIA_PASSWORD`) so the movers in that namespace can open the repository.

⚠️ The aKeyless key it reads is `/kubernetes/volsync`, not `/kubernetes/kopiur` — a leftover from before [ADR-0013](../adr/0013-kopiur-over-volsync.md). Renaming it means updating the secret in aKeyless and the component together.
