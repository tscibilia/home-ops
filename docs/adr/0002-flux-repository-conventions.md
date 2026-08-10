# Flux repository conventions

**Status:** accepted
**Date:** — (accreted from 2025-03-24 onward)

The conventions below govern how every app is expressed in this repo. None was decided on an identifiable day — they accreted, were enforced by review, and are now load-bearing enough that a reasonable person would otherwise "fix" them. They are recorded here so that does not happen.

Like ADR-0001, this is a **living record**: the `Status` column changes as individual conventions are adopted or retired, and the reference material below the table is updated in place as the tooling changes. It is the second and last exception to the write-once rule — see `docs/agents/domain.md`.

## Conventions

| Convention                                                                                      | Rationale                                                                                                                                                                                                                                                                                                       | Status   |
| ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Routes are inline in the HelmRelease `values.route` block, not standalone `HTTPRoute` manifests | One file per app to read, and the chart already templates the route. A standalone `httproute.yaml` is used only where the chart can't express it — no route support in the chart (`flux-webhook` on `flux-instance`, `kopiur`, `grafana-operator`), or path-level auth (`kube-prometheus-stack`'s remote-write) | accepted |
| App components go in `ks.yaml` `spec.components`, never the app's `kustomization.yaml`          | They need `postBuild` substitution, which only the Flux Kustomization provides. These are `auth`, `cnpg`, `kopiur/backup`, `zeroscaler`                                                                                                                                                                         | accepted |
| Namespace components go in `kubernetes/apps/{ns}/kustomization.yaml` under `components:`        | They take no substitutions and apply to every app in the namespace, so there is nothing per-app to declare. These are `alerts`, `alerts/github-status`, `secrets`, `kopiur/secret`                                                                                                                              | accepted |
| `dependsOn` is always declared, and references Kustomization names — not HelmRelease names      | They are different objects; the failure is silent and reconciliation-ordering bugs are expensive to diagnose                                                                                                                                                                                                    | accepted |
| `APP: *app` is always set in `postBuild.substitute`, via a YAML anchor on `metadata.name`       | Every app component depends on `${APP}`; the anchor keeps one source for the name                                                                                                                                                                                                                               | accepted |
| `substituteFrom: cluster-secrets` on apps that consume a cluster-wide var                       | Most apps need `${SECRET_DOMAIN}` for their route, so it's the common case — but it is not unconditional. An app referencing no cluster-secrets var doesn't declare it. `${TIMEZONE}` is now rarely needed: `k8tz` injects timezone at admission                                                                | accepted |
| `kustomize.toolkit.fluxcd.io/substitute: disabled` on generated ConfigMaps                      | Config files legitimately contain `${...}`; without this, Flux mangles them                                                                                                                                                                                                                                     | accepted |
| `# renovate:` comments only where no manager auto-detects the version                           | The flux/helm-values/kubernetes managers already scan all `.yaml`/`.yml`/`.j2`; redundant comments drift                                                                                                                                                                                                        | accepted |
| `wait: false` unless the app has multiple sub-Kustomizations                                    | `wait: true` serialises reconciliation for no benefit on single-Kustomization apps                                                                                                                                                                                                                              | accepted |

## ⚠️ Gotchas

- **`dependsOn` uses Kustomization names:** references the Kustomization resource name defined in `ks.yaml`, NOT the HelmRelease name — different objects.
- **`kubectl edit` is ephemeral:** overwritten by the next Flux reconciliation. All changes go through git.
- **`apply-ks` touches the live cluster:** `just kube apply-ks` runs server-side apply against the live API without pushing to git — not a dry run; do not run it speculatively.

## Local rendering

`flate` (konflate) renders manifests locally — see ADR-0012. `FLATE_PATH` points at `kubernetes/flux/cluster`.

| Command                               | Purpose                                                        |
| ------------------------------------- | -------------------------------------------------------------- |
| `flate test all`                      | Validate all Kustomizations, HelmReleases, and source CRs      |
| `flate build all`                     | Render entire cluster to YAML                                  |
| `flate build ks -n <ns> <name>`       | Render a specific Kustomization                                |
| `flate build hr -n <ns> <name>`       | Render a specific HelmRelease                                  |
| `just kube render-local-ks <ns> <ks>` | Internal — wraps `flate build ks` for `apply-ks` / `delete-ks` |

## ks.yaml anatomy

Every app has a `ks.yaml` at `kubernetes/apps/{namespace}/{app}/ks.yaml`.

```yaml
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app myapp # YAML anchor — reused below as *app
spec:
    components: # optional — add kopiur, cnpg, auth, zeroscaler
        - ../../../../components/kopiur/backup
    dependsOn: # always declare; see chains below
        - name: secret-stores
          namespace: external-secrets
    interval: 1h
    path: ./kubernetes/apps/default/myapp/app
    postBuild:
        substitute:
            APP: *app # always set APP — components depend on it
            GATUS_SUBDOMAIN: sub # sets monitoring URL subdomain
            GATUS_PATH: /health # optional, default is /
            KOPIUR_CAPACITY: 5Gi # optional; defaults in components.md
        substituteFrom:
            - kind: Secret
              name: cluster-secrets # always include for SECRET_DOMAIN, TIMEZONE etc
    prune: true
    sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
    targetNamespace: default
    wait: false # true only for apps with multiple sub-Kustomizations
```

## Common dependsOn chains

| Condition                          | Add to dependsOn                                                             |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| Always (has ExternalSecret)        | `secret-stores` / `external-secrets`                                         |
| Using kopiur component             | `secret-stores` / `external-secrets` + `kopiur` / `kopiur-system`            |
| Using cnpg component               | `cnpg-cluster` / `database`                                                  |
| Using ceph-ssd storage (no kopiur) | `rook-ceph-cluster` / `rook-ceph`                                            |
| Using zeroscaler                   | (no extra dependsOn — HPA gracefully degrades if prometheus-adapter is down) |
| Depends on another app (same ns)   | just `name:` without `namespace:`                                            |

## Namespace kustomization.yaml

After creating `ks.yaml`, add it to the namespace index or Flux will never reconcile it. The index also carries the namespace components — the ones that apply to every app in the namespace and take no substitutions:

```yaml
# kubernetes/apps/{namespace}/kustomization.yaml
resources:
    - ./myapp/ks.yaml
components:
    - ../../components/alerts
    - ../../components/secrets
    - ../../components/kopiur/secret # only where the namespace has kopiur-backed apps
```

App components (`auth`, `cnpg`, `kopiur/backup`, `zeroscaler`) go in the app's own `ks.yaml` instead — see `docs/context/components.md`.

## HelmRelease schema

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
```

Most apps use the `bjw-s/app-template` chart. OCI source via `OCIRepository`.

## configMapGenerator

Use for embedding config files rather than inline values:

```yaml
# kubernetes/apps/{ns}/{app}/app/kustomization.yaml
configMapGenerator:
    - name: myapp-config
      files:
          - config.yaml=./resources/config.yaml
generatorOptions:
    disableNameSuffixHash: true
    annotations:
        kustomize.toolkit.fluxcd.io/substitute: disabled # prevents variable substitution in config files
```

## Sub-Kustomizations

Some apps split into multiple Kustomizations (e.g. `grafana/operator` + `grafana/instance`):

- Parent `ks.yaml` is one file with multiple Kustomization resources
- Child Kustomizations use `dependsOn` to sequence themselves
- Parent sets `wait: false`

## Consequences

- These are conventions, not schema — nothing enforces them mechanically. `flate test all` validates structure, not adherence.
- This ADR carries reference material that will drift as tooling changes; unlike every ADR except 0001, it is expected to be updated rather than superseded.
