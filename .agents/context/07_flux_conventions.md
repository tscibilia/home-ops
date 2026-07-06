# Flux Conventions

## ⚠️ Gotchas & Interactions

- **dependsOn uses Kustomization names:** `dependsOn` references the Kustomization resource name (defined in `ks.yaml`), NOT the HelmRelease name — these are different objects.
- **kubectl edit is ephemeral:** Any `kubectl edit` change is overwritten by the next Flux reconciliation. All changes must go through git.
- **apply-ks touches the live cluster:** `just kube apply-ks` runs server-side apply against the live cluster API without pushing to git — it is not a dry run; do not run it speculatively.
- **No renovate inline comments:** Never add `# renovate:` inline comments to YAML. This repo does not use them.

## Local Rendering

`flate` (konflate) replaces `flux-local` for all local manifest rendering. The `FLATE_PATH` env var points to `kubernetes/flux/cluster`.

| Command                               | Purpose                                                        |
| ------------------------------------- | -------------------------------------------------------------- |
| `flate test all`                      | Validate all Kustomizations, HelmReleases, and source CRs      |
| `flate build all`                     | Render entire cluster to YAML                                  |
| `flate build ks -n <ns> <name>`       | Render a specific Kustomization                                |
| `flate build hr -n <ns> <name>`       | Render a specific HelmRelease                                  |
| `just kube render-local-ks <ns> <ks>` | Internal — wraps `flate build ks` for `apply-ks` / `delete-ks` |

## ks.yaml Anatomy

Every app has a `ks.yaml` at `kubernetes/apps/{namespace}/{app}/ks.yaml`. Annotated example:

```yaml
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app myapp # YAML anchor — reused below as *app
spec:
    components: # optional — add kopiur, cnpg, ext-auth, zeroscaler
        - ../../../../components/kopiur/backup
    dependsOn: # always declare; see common chains below
        - name: secret-stores
          namespace: external-secrets
    interval: 1h
    path: ./kubernetes/apps/default/myapp/app
    postBuild:
        substitute:
            APP: *app # always set APP — components depend on it
            GATUS_SUBDOMAIN: sub # sets monitoring URL subdomain
            GATUS_PATH: /health # optional, default is /
            KOPIUR_CAPACITY: 5Gi # optional; defaults in 04_storage.md
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

## Common dependsOn Chains

| Condition                          | Add to dependsOn                                                             |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| Always (has ExternalSecret)        | `secret-stores` / `external-secrets`                                         |
| Using kopiur component             | `secret-stores` / `external-secrets` + `kopiur` / `kopiur-system`            |
| Using cnpg component               | `cnpg-cluster` / `database`                                                  |
| Using ceph-ssd storage (no kopiur) | `rook-ceph-cluster` / `rook-ceph`                                            |
| Using zeroscaler                   | (no extra dependsOn — HPA gracefully degrades if prometheus-adapter is down) |
| Depends on another app (same ns)   | just `name:` without `namespace:`                                            |

## Namespace kustomization.yaml

After creating `ks.yaml`, add it to the namespace index:

```yaml
# kubernetes/apps/{namespace}/kustomization.yaml
resources:
    - ./myapp/ks.yaml
```

## HelmRelease Schema

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

Some apps split into multiple Kustomizations (e.g. `grafana/operator` + `grafana/instance`). In this case:

- Parent `ks.yaml` is one file with multiple Kustomization resources
- Child Kustomizations use `dependsOn` to sequence themselves
- Parent sets `wait: false`
