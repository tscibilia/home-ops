# Kustomize Components

## ⚠️ Gotchas & Interactions

- **zeroscaler requires a prometheus-adapter metric:** Adding the `zeroscaler` component to `ks.yaml` is not enough — the app also needs a custom metric entry in the `prometheus-adapter` ConfigMap. Component without metric = scaling never triggers, silently.
- **cnpg does not create the database:** the component only supplies the credentials. The app's HelmRelease must declare the `postgres-init` initContainer that actually creates the role and database — adding the component alone leaves the app starting against a database that does not exist.
- **Regenerate the inventory:** Adding or removing an app component changes the app's `[flags]` in `apps.md`. Run `just docs generate` — that list is rendered from disk, not hand-edited.
- **The kopiur webhook gates every app that uses `kopiur/backup`:** its MutatingWebhookConfiguration has `failurePolicy: Fail` and an empty `namespaceSelector`, so while the webhook is unreachable _every_ kopiur CR write fails and the Flux Kustomization dry-run breaks for all ~39 apps at once. It runs 2 replicas with a PDB and a hostname topology spread so a node drain cannot take it to zero — do not drop it back to one replica, and never "fix" a failure by setting `failurePolicy: Ignore`, which silently skips defaulting.
- **Placement is not interchangeable:** An app component in a namespace `kustomization.yaml` applies to every app in the namespace; a namespace component in a `ks.yaml` is missing the substitutions it never had. Check which kind you are adding before you add it.

Components live in `kubernetes/components/`. They come in two kinds, and the difference is where they are declared:

| Kind                    | Declared in                               | Configured by             | Components                                    |
| ----------------------- | ----------------------------------------- | ------------------------- | --------------------------------------------- |
| **app component**       | `ks.yaml` → `spec.components`             | `postBuild.substitute`    | `auth`, `cnpg`, `kopiur/backup`, `zeroscaler` |
| **namespace component** | `kubernetes/apps/{ns}/kustomization.yaml` | nothing — no per-app vars | `alerts`, `secrets`, `kopiur/secret`          |

Neither kind ever goes in an app's own `app/kustomization.yaml`.

Each section below is complete: everything a component needs in a `ks.yaml` is stated here, not split across topic files. [ADR-0002](../adr/0002-flux-repository-conventions.md) owns the _shape_ of a `ks.yaml`; this file owns what each component _needs_ in one.

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
        KOPIUR_CAPACITY: 5Gi
dependsOn:
    - name: secret-stores
      namespace: external-secrets
    - name: kopiur
      namespace: kopiur-system
```

`APP` is the only required substitution. The rest have defaults:

| Var                    | Default              | Purpose                |
| ---------------------- | -------------------- | ---------------------- |
| `KOPIUR_ACCESSMODES`   | `ReadWriteOnce`      | PVC access mode        |
| `KOPIUR_CAPACITY`      | `5Gi`                | PVC size               |
| `KOPIUR_STORAGECLASS`  | `ceph-ssd`           | PVC storage class      |
| `KOPIUR_SNAPSHOTCLASS` | `csi-ceph-blockpool` | VolumeSnapshotClass    |
| `KOPIUR_CRON`          | `0 */4 * * *`        | Snapshot schedule cron |
| `KOPIUR_PUID`          | `1000`               | mover runAsUser        |
| `KOPIUR_PGID`          | `1000`               | mover runAsGroup       |

The repository password comes from the `kopiur/secret` namespace component — see below. Do not add it per app.

**Restore:** edit the `Restore` CR (named `${APP}`, in the app's namespace) and set `spec.offset` to the number of snapshots back you want (0 = latest). The PVC is re-populated via the CSI populator; then delete and recreate the pod to mount it.

### cnpg — PostgreSQL credentials + pgdump CronJob

```yaml
# ks.yaml
components:
    - ../../../../components/cnpg
postBuild:
    substitute:
        APP: *app
        CNPG_NAME: &postgresAppName pgcluster-default # or pgcluster-vector
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
interval: 1h
retryInterval: 5m
```

`retryInterval` is load-bearing here. The health check marks the Kustomization failed whenever the
cluster goes `Ready: False` — a CNPG image bump does that on every rolling restart. Flux defaults
`retryInterval` to `interval`, so without this line the app stays failed for a full hour after the
database recovers, and only a manual `just kube reconcile-ks` clears it sooner.

Creates three resources in the app's namespace:

| Resource               | Kind           | Purpose                                                                             |
| ---------------------- | -------------- | ----------------------------------------------------------------------------------- |
| `${APP}-pguser-secret` | ExternalSecret | App credentials — `host`, `ro_host`, `port`, `user`, `password`, `db`, `uri`, `dsn` |
| `${APP}-initdb-secret` | ExternalSecret | `INIT_POSTGRES_*` vars for the init container                                       |
| `${APP}-pg-backups`    | CronJob        | pgdump to NFS on clonenas, `5 */4 * * *`                                            |

`PG_VER` (default `18`) selects the `postgres-backup-local` image tag for that CronJob — override it only if the app's cluster runs a different major version. `memini` and `immich` pin `17` because they are on `pgcluster-vector`, which is still PostgreSQL 17.

The component stops at credentials. The app's HelmRelease has to run the init container that creates the role and database:

```yaml
# HelmRelease values — required alongside the cnpg component
initContainers:
    init-db:
        image:
            repository: ghcr.io/home-operations/postgres-init
            tag: # grep the repo for the tag+digest currently in use
        envFrom:
            - secretRef:
                  name: "{{ .Release.Name }}-initdb-secret"
```

`CNPG_NAME` picks the cluster: `pgcluster-default` for general apps, `pgcluster-vector` for apps needing vector search ([ADR-0011](../adr/0011-pgvector-cluster-split.md)). It defaults to `pgcluster-default` in the component (`${CNPG_NAME:=pgcluster-default}`) — but set it explicitly anyway, because the `healthChecks` block below needs the anchor. Both clusters live in the `database` namespace; `storage.md` says what each is for.

The generated `host` is `{cluster}-rw…`, shared by every app on that cluster — apps read it from the Secret, they never compose it.

The app's Postgres password is not created by the component. Add it to aKeyless first, or the generated Secret comes up empty:

```bash
export APP=myapp
PASSWORD=$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 20)
akeyless update-secret-val \
  --name cnpg-users \
  --custom-field "${APP}_postgres_username=${APP}" \
  --custom-field "${APP}_postgres_password=${PASSWORD}"
```

### auth — tinyauth forward auth

One component for **both** gateways — there is no internal/external split. Add to the **Flux Kustomization (`ks.yaml`)** `spec.components` (not the app's `kustomization.yaml`):

```yaml
# kubernetes/apps/{ns}/{app}/ks.yaml
spec:
    components:
        - ../../../../components/auth
```

Creates a `SecurityPolicy` routing ext-auth to `tinyauth.security:3000`, targeting the HTTPRoute named `${APP}`.

No `dependsOn` — the SecurityPolicy resolves tinyauth at request time, not at reconcile time. Apps using this component depend only on `secret-stores` (and `kopiur` if they back up).

**Substitution variables:**

| Var                  | Default                     | Purpose                      |
| -------------------- | --------------------------- | ---------------------------- |
| `${EXT_AUTH_TARGET}` | `${APP}`                    | Name of the targeted route   |
| `${EXT_AUTH_KIND}`   | `HTTPRoute`                 | Target kind (e.g. `Gateway`) |
| `${EXT_AUTH_GROUP}`  | `gateway.networking.k8s.io` | Target API group             |

**Gatus annotations must be swapped.** The tinyauth redirect means the route never returns 200, so route monitoring has to move to the service — otherwise the app shows permanently down:

```yaml
# HelmRelease values
route:
    app:
        annotations:
            gatus.home-operations.com/enabled: "false"
service:
    app:
        annotations:
            gatus.home-operations.com/enabled: "true"
```

Use this **only** for apps that cannot do OIDC themselves. Apps with native OIDC get a `PocketIDOIDCClient` CR instead and no component — that path is not a component at all, and is documented in `networking.md`. Never apply both to one app. ([ADR-0014](../adr/0014-pocket-id-tinyauth-over-authentik.md))

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

Every namespace. Creates a Flux `Provider` pointing at `alertmanager-operated.observability.svc.cluster.local:9093` and an `Alert` at `eventSeverity: error` covering every Flux kind (FluxInstance, GitRepository, HelmRelease, HelmRepository, Kustomization, OCIRepository). Carries an `exclusionList` for known-noisy errors (GitHub lookup failures, TCP dial timeouts, socket waits).

`components/alerts/github-status/` sits beside it but is **not** a component — it is `kind: Kustomization`, commented out of the parent `alerts` component after hitting GitHub secondary rate limits, and pulled in by `flux-system` alone under `resources:`, not `components:`.

### secrets — the cluster-secrets Secret

Every namespace. Creates the `cluster-secrets` ExternalSecret, which is what makes `substituteFrom: cluster-secrets` resolve in that namespace. Keys: `SECRET_DOMAIN`, `CEAPP_DOMAIN`, `TIMEZONE`, `TAILSCALE_MAGICDNS`, `KOPIA_BUCKET`, drawn from three aKeyless paths (`/kubernetes/cluster-secrets`, `/network/tailscale/operator`, `/cloud-providers/b2-creds`). See `secrets.md`.

The same file also declares the `password10` / `password32` / `password64` `Password` generator CRs. Being namespace-scoped, they only exist where this component is applied — which is why an app references one by name rather than declaring its own. See `secrets.md`.

### kopiur/secret — the Kopia repository password

Only namespaces containing kopiur-backed apps. Creates `kopiur-nas-secret` (`KOPIA_PASSWORD`) so the movers in that namespace can open the repository.

⚠️ The aKeyless key it reads is `/kubernetes/volsync`, not `/kubernetes/kopiur` — a leftover from before [ADR-0013](../adr/0013-kopiur-over-volsync.md). Renaming it means updating the secret in aKeyless and the component together.
<!-- verify-ignore: akeyless /kubernetes/kopiur -->  named deliberately above as the path that does *not* exist
