---
name: add-app
description: >-
    Use when adding an app to the cluster — "add app X to the cluster", or /add-app.
    Scaffolds kubernetes/apps/{namespace}/{app}/ (Flux Kustomization + app-template HelmRelease),
    wires components and secrets from the docs, and verifies the result with flate and docs gates.
---

# Add an app

Scaffolds one app under `kubernetes/apps/{namespace}/{app}/`: `ks.yaml` plus `app/`.

**Scope:** app-template apps. A custom OCI chart follows
[references/features.md](references/features.md) → custom chart and gets no generated values.
Operator CRs and raw manifests are not this skill — say so and stop.

**The repo is the source, not this file.** Stanzas, versions, and flags are read at run
time. If a source and this skill disagree, the source wins.

## Step 1 — Collect the inputs

Stop for any missing mandatory value. Generated YAML contains no `TODO`, no `latest`, and
no guessed value.

| Input            | Notes                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------- |
| app name         | kebab-case; directory, `metadata.name`, and the `&app` anchor                             |
| namespace        | confirm against the generated inventory                                                   |
| image repository | upstream image                                                                            |
| image tag        | `version@sha256:…` preferred; a pinned version is acceptable; `latest` and `main` refused |
| container port   | the port the app listens on                                                               |
| exposure         | `envoy-internal`, `envoy-external`, or none                                               |
| health path      | probes and Gatus; required unless exposure is none                                        |
| subdomain        | required unless exposure is none; omit `GATUS_SUBDOMAIN` when it equals the app name      |
| persistence      | yes/no; if yes, capacity (default `5Gi`) and the kopiur pairing in `ks.yaml`              |
| auth             | none, native OIDC, or forward auth                                                        |
| config files     | none, mounted config file, or config file rendered with secrets                           |
| dependencies     | extra `dependsOn` entries, if any                                                         |

Unknown app-internal values (env var names, callback path, config body) are gaps, not
inputs. Report each as `file: key — needs X` in Step 6.

Ask only for missing values, in one form.

## Step 2 — Read the sources

| Question                                                          | Source                                |
| ----------------------------------------------------------------- | ------------------------------------- |
| Does the namespace exist? Which flags does the app already have?  | `docs/context/apps.md` (generated)    |
| App or namespace component stanza and substitutions               | `docs/context/components.md`          |
| Route, native OIDC, forward auth, Gatus                           | `docs/context/networking.md`          |
| ExternalSecret, generators, seeded CNPG password, OIDC PushSecret | `docs/context/secrets.md`             |
| Storage class, NFS, CNPG cluster                                  | `docs/context/storage.md`             |
| Field order                                                       | `docs/agents/sorting-instructions.md` |
| Vocabulary                                                        | `CONTEXT.md` glossary                 |
| Shape to copy                                                     | reference app for the branch (below)  |

### Reference apps

| Branch                              | Reference app                         |
| ----------------------------------- | ------------------------------------- |
| base app-template, route, probes    | `kubernetes/apps/observability/karma` |
| app secrets as env vars             | `kubernetes/apps/media/imagemaid`     |
| PVC + kopiur backup                 | `kubernetes/apps/default/radicale`    |
| CNPG, including the seeded password | `kubernetes/apps/media/airwave`       |
| native OIDC                         | `kubernetes/apps/default/kept`        |
| forward auth + zeroscaler           | `kubernetes/apps/media/bazarr`        |
| script files kept byte-exact        | `kubernetes/apps/media/sonarr`        |
| config file rendered with secrets   | `kubernetes/apps/default/immich`      |

Copy the shape and delete everything the app does not need — karma's config file,
`serviceMonitor`, and `runAsUser: 568` are examples, not defaults. The defaults below win
over any reference app's values.

### Versions — read, never recall

```bash
# app-template chart tag (repo mode across app-template OCIRepositories)
for f in kubernetes/apps/*/*/app/ocirepository.yaml; do
  yq -r 'select(.spec.url == "oci://ghcr.io/bjw-s-labs/helm/app-template") | .spec.ref.tag' "$f"
done | sort | uniq -c | sort -rn | head -1

# postgres-init tag (only with CNPG)
for f in kubernetes/apps/*/*/app/helmrelease.yaml; do
  yq -r '(.. | select(has("repository"))) | select(.repository == "ghcr.io/home-operations/postgres-init") | .tag' "$f"
done | sort | uniq -c | sort -rn | head -1
```

## Step 3 — Write the app

| File                          | When                                               |
| ----------------------------- | -------------------------------------------------- |
| `ks.yaml`                     | always                                             |
| `app/kustomization.yaml`      | always                                             |
| `app/ocirepository.yaml`      | always                                             |
| `app/helmrelease.yaml`        | always                                             |
| `app/externalsecret.yaml`     | the app reads secrets                              |
| `app/pocketidoidcclient.yaml` | auth is native OIDC                                |
| `app/pushsecret.yaml`         | native OIDC and/or seeded CNPG password            |
| `app/resources/`              | config file, script files, or ESO-templated config |

**`ks.yaml` carries:** `components` for the selected app components; `dependsOn` on
`secret-stores` whenever the app reads secrets (except bootstrap apps: `cert-manager`,
`flux-instance`, `rook-ceph`, `kube-prometheus-stack`), plus `kopiur`, `cnpg-pgcluster-default`, or
`pocket-id` as selected; `interval: 1h`; `path`; `postBuild.substitute.APP`; `GATUS_PATH` set to the health path;
`GATUS_SUBDOMAIN` when it differs from the app name; `postBuild.substituteFrom` the
`cluster-secrets` Secret; `retryInterval: 5m` with CNPG; `healthChecks` and
`healthCheckExprs` with CNPG; `prune: true`; `sourceRef`; `targetNamespace`.

**The HelmRelease carries:** `chartRef` to the app's OCIRepository; `interval: 1h`;
`values.controllers.<name>` with the app container; `values.service`; `values.route` when
exposed; `values.persistence` for PVC, config, or emptyDir mounts.

### Defaults (repo mode)

- Controller annotation `reloader.stakater.com/auto: "true"` on every controller that reads a
  Secret or ConfigMap. A sidecar that consumes neither does not need it. When only one input
  matters, the targeted `secret.reloader.stakater.com/reload` or
  `configmap.reloader.stakater.com/reload` is equivalent.
- Custom probes — anchor the full `liveness` block with `&probes` and its `spec` with
  `&probeSpec`; merge `readiness` and `startup` with `<<: *probes` and
  `<<: *probeSpec`. Put `httpGet` on `${GATUS_PATH}` as in `karma`; add `startup` with
  `failureThreshold: 30` and `periodSeconds: 10`. Use distinct anchor names
  (`&dashboardProbes`, `&codeserverProbes`) when one file has multiple controllers.
- Pod security context: `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`;
  add `fsGroup: 1000` and `fsGroupChangePolicy: OnRootMismatch` when a PVC is mounted.
- Container security context: `allowPrivilegeEscalation: false`,
  `readOnlyRootFilesystem: true`, `capabilities: { drop: [ALL] }`. Every container needs its
  own block, sidecars and init containers included; anchor it (`&securityContext`) when they
  share one.
- `drop: [ALL]` is the baseline, not a blind default. Verify the image's Dockerfile,
  entrypoint, and upstream docs before dropping. Entrypoints that chown or drop privileges
  need `CHOWN`, `SETUID`, `SETGID`, or `DAC_OVERRIDE`; ports below 1024 need
  `NET_BIND_SERVICE`; device or network integrations may need `NET_ADMIN`, `SYS_RAWIO`, or
  `privileged`. Keep `drop: [ALL]` and add only the verified capability. If the requirement
  is not verified upstream, stop and report the gap instead of changing the security context.
  Never mass-apply a security-context change across apps.
- Resources: `requests: { cpu: 20m, memory: 128Mi }`, `limits: { memory: 512Mi }`. They are
  per container, set on sidecars too, and are not anchored.
- `readOnlyRootFilesystem: true` makes every path the image writes fail unless it is mounted:
  mount a `tmpfs` emptyDir at each writable path (e.g. `/tmp`). The persistence key is a volume
  name, not the path. Declaring an emptyDir without mounting it is dead config. Use
  `medium: Memory` only when scratch must be RAM-backed.
- 2-space indentation, `&app`/`*app`, and `&port` when the app exposes a port.

Deviate for a documented image requirement or measured need, and say why in the report.

### Do not restate cluster defaults

`kubernetes/flux/cluster/ks.yaml` patches every app Kustomization and HelmRelease with
`deletionPolicy: WaitForTermination`, plus the HelmRelease `install`, `upgrade`, `rollback`,
`maxHistory`, and `uninstall` settings. No app file repeats those values; a deliberate
non-default override is fine, but say why. No app `ks.yaml` carries a `patches:` block.

### Wait

Omit `wait` on a normal app — it defaults to `false`, and explicit `wait: false` is redundant
boilerplate. Set `wait: true` only when another Kustomization `dependsOn` this one and this
Kustomization defines no `healthChecks`/`healthCheckExprs`. Flux ignores those checks when
`wait` is true, so never set both.

### Persistence is a pair

A backed-up volume is two halves: `persistence.<name>.existingClaim: *app` in the
HelmRelease, and the `kopiur/backup` component in `ks.yaml` with `APP` and
`KOPIUR_CAPACITY`. The component creates the PVC named `${APP}`; the HelmRelease mounts it.
One without the other gives an unbacked volume, or a component pointing at a claim that does
not exist.

### Secrets

- Name the app's env-secret ExternalSecret and its Secret `<app>-secret` (singular), and
  anchor the name `&name`. Purpose-scoped secrets may use `<app>-<purpose>` — `-config`,
  `-ghcr-pull`, `-deploykey`; never `<app>-secrets`.
- Prefer `dataFrom.extract` when the aKeyless item is a JSON object. Use `data` with
  `remoteRef` for a single non-JSON value, such as a shared credential stored alone. Map the
  result into the env var names the app expects under `target.template.data`.
- Consume the Secret with `envFrom.secretRef.name: "{{ .Release.Name }}-secret"`, or
  `secretKeyRef` for individual keys. Never hand-write a Secret manifest.

### Names

Use `*app` where the `&app` anchor is in the same file. Use `{{ .Release.Name }}` inside
HelmRelease values for release-derived names — `<name>-secret`, `<name>-configmap`, and the
route hostname — because Flux renders the release name, not the YAML anchor.

### Rules the context docs do not own

- Hostname: `{{ .Release.Name }}.${SECRET_DOMAIN}` when the subdomain equals the app name;
  `${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}` otherwise.
- Gatus + forward auth: move monitoring from the route to the service — stanza in
  `components.md` → `auth`.
- CNPG password: never create it by hand. The `${APP}-pgpass` ExternalSecret plus
  `PushSecret` pair seeds it; see `secrets.md` → Seeded CNPG passwords.
- No Renovate annotations; Renovate discovers images from the repo.
- No `namespace.yaml`; namespaces already exist.

## Step 4 — Register

- Append `./{app}/ks.yaml` to `kubernetes/apps/{namespace}/kustomization.yaml` under
  `resources`, in alphabetical position.
- If the namespace is not in the inventory, stop — creating one is a separate change.
- Run `just docs generate`, then add `_(description)_` by hand if the app needs one —
  descriptions survive regeneration (six words max).

## Step 5 — Verify

Run, in order:

```bash
flate test all
kustomize build kubernetes/apps/{namespace}/{app}/app
just docs generate
just docs test
```

`flate` needs `just kube registry-auth` once per machine. If it cannot run, report "not
run" and why. Report exactly which checks ran and their result; a render error fails the
step, it is not a note.

## Step 6 — Report

- Files created, and the reference app behind each branch.
- Gaps as `file: key — needs X`, one line each.
- Next steps: confirm the image tag, callback path, env mappings, and config body.

## Common mistakes

- **Copying a version or tag from this skill or memory** — read the chart and postgres-init
  versions from the repo (Step 2) and the image tag from upstream.
- **Restating cluster defaults** — no duplicated `install`/`upgrade`/`rollback`/`maxHistory`/
  `uninstall` values, no `deletionPolicy`, no `patches:` in an app `ks.yaml`. A deliberate
  override is not a restatement.
- **Using volsync** — that component no longer exists; kopiur replaced it.
- **Adding a PVC without the kopiur block**, or the kopiur block without mounting the claim.
- **`readOnlyRootFilesystem: true` with an unmounted writable path** — the app crashes on its
  first write; mount an emptyDir for every path it writes.
- **Forgetting `reloader.stakater.com/auto`** — a controller that reads a Secret or ConfigMap
  does not restart when it changes.
- **Skipping sidecar containers** — each container needs its own securityContext and resources.
- **Inventing ESO key names or Secret names** — use `<app>-secret` and reuse keys already in
  the repo for shared services.
- **Adding `wait: false`, `commonMetadata`, or `timeout`** — boilerplate; omit all three.
  `wait: true` only for a real dependent gate with no health checks.
- **Adding a CiliumNetworkPolicy by default** — only when the app needs one.
- **Skipping the sorting conventions** — `docs/agents/sorting-instructions.md`.
- **Creating the CNPG password by hand** — the `-pgpass` pair seeds it.
- **Adding `namespace.yaml`** — namespaces already exist.
