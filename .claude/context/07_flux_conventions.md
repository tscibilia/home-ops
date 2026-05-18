# Flux Conventions

## ⚠️ Gotchas & Interactions

- **dependsOn uses Kustomization names:** `dependsOn` references the Kustomization resource name (defined in `ks.yaml`), NOT the HelmRelease name — these are different objects.
- **kubectl edit is ephemeral:** Any `kubectl edit` change is overwritten by the next Flux reconciliation. All changes must go through git.
- **apply-ks touches the live cluster:** `just kube apply-ks` runs `flux-local` validation against the live cluster API — it is not a dry run; do not run it speculatively.
- **No renovate inline comments:** Never add `# renovate:` inline comments to YAML. This repo does not use them.

## ks.yaml Anatomy

Every app has a `ks.yaml` at `kubernetes/apps/{namespace}/{app}/ks.yaml`. Annotated example:

```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app myapp          # YAML anchor — reused below as *app
spec:
  components:               # optional — add volsync, cnpg, ext-auth, zeroscaler
    - ../../../../components/volsync
  dependsOn:                # always declare; see common chains below
    - name: secret-stores
      namespace: external-secrets
  interval: 1h
  path: ./kubernetes/apps/default/myapp/app
  postBuild:
    substitute:
      APP: *app             # always set APP — components depend on it
      GATUS_SUBDOMAIN: sub  # sets monitoring URL subdomain
      GATUS_PATH: /health   # optional, default is /
      VOLSYNC_CAPACITY: 5Gi # required when using volsync component
    substituteFrom:
      - kind: Secret
        name: cluster-secrets   # always include for SECRET_DOMAIN, TIMEZONE etc
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: default
  wait: true    # false for apps with multiple sub-Kustomizations
```

## Common dependsOn Chains

| Condition | Add to dependsOn |
|-----------|-----------------|
| Always (has ExternalSecret) | `secret-stores` / `external-secrets` |
| Using volsync component | `rook-ceph-cluster` / `rook-ceph` + `volsync` / `volsync-system` |
| Using cnpg component | `cnpg-cluster` / `database` |
| Using ceph-ssd storage (no volsync) | `rook-ceph-cluster` / `rook-ceph` |
| Using zeroscaler | (no extra dependsOn — HPA gracefully degrades if prometheus-adapter is down) |
| Depends on another app (same ns) | just `name:` without `namespace:` |

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
    kustomize.toolkit.fluxcd.io/substitute: disabled  # prevents variable substitution in config files
```

## Sub-Kustomizations

Some apps split into multiple Kustomizations (e.g. `grafana/operator` + `grafana/instance`). In this case:
- Parent `ks.yaml` is one file with multiple Kustomization resources
- Child Kustomizations use `dependsOn` to sequence themselves
- Parent sets `wait: false`
