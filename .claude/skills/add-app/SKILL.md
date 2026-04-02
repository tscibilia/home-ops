---
name: add-app
description: Scaffold a new Kubernetes app in the home-ops monorepo. Prompts for app name, namespace, helm chart type, and optional features (volsync, cnpg, auth, keda, gatus, ESO, configMapGenerator, ingress). Generates all manifests following repo conventions.
---

# Add App Skill

Interactive scaffold for adding a new Flux-managed Kubernetes app to this monorepo.

## Workflow

### Phase 1 — Gather Inputs

Use `AskUserQuestion` to collect the following. Ask up to 4 questions per call, batch logically.

**Batch 1 — Identity:**

1. **App name** (free text via "Other"): The kebab-case name used for directory, metadata, and YAML anchors. Offer 2-3 common suggestions if the user mentioned an app, otherwise present two placeholder options and let them type via Other.
2. **Namespace**: Which namespace? Options: `default`, `media`, `home-automation`, `observability`, `network`. Let them type Other for a new one.

**Batch 2 — Helm & Ingress:**

3. **Helm chart type**:
   - `app-template` (Recommended) — bjw-s app-template (most apps use this)
   - `Custom chart` — third-party Helm chart (provide OCI URL + chart name)
4. **Ingress exposure**:
   - `Internal only` (Recommended) — envoy-internal gateway, LAN access only
   - `External` — envoy-external gateway, accessible via Cloudflare tunnel
   - `None` — no HTTP route (headless service, CLI tool, background worker)

**Batch 3 — Features (multi-select):**

5. **Which optional features does this app need?** (multiSelect: true)
   - `VolSync backups` — PVC backup/restore via restic (needs VOLSYNC_CAPACITY)
   - `CNPG PostgreSQL` — shared PostgreSQL database via cnpg component
   - `KEDA NFS scaler` — scale to zero when TrueNAS NFS is down
   - `KEDA NFS backup scaler` — scale to zero when UnRaid NFS is down

**Batch 4 — Auth & Config (conditional — only ask if ingress is NOT "None"):**

6. **Authentication method**:
   - `None` — app handles its own auth or no auth needed
   - `OIDC (native)` — app supports OIDC natively; just needs ESO secrets for Authentik
   - `Forward auth (internal)` — ext-auth-internal component (Authentik, LAN only)
   - `Forward auth (external)` — ext-auth-external component (Authentik, public)

**Batch 5 — Gatus & Config details (conditional):**

7. **Gatus subdomain** (only if ingress is not "None"): If the subdomain differs from the app name, ask. Default is the app name. Also ask for the health check path (default `/`).
   - Offer: `Same as app name (Recommended)`, or Other for custom subdomain.

8. **Config style** (only if app-template):
   - `Inline env vars only` (Recommended) — all config via env vars in HelmRelease
   - `ConfigMapGenerator + ESO` — external config file templated with secrets (like immich pattern: configMapGenerator in kustomization.yaml + kustomizeconfig.yaml + ExternalSecret templateFrom)

### Phase 2 — Generate Manifests

After collecting inputs, generate all files. Write each file using the Write tool. **Do not return file contents inline.**

#### Directory structure

```
kubernetes/apps/{namespace}/{app-name}/
├── ks.yaml
└── app/
    ├── kustomization.yaml
    ├── helmrelease.yaml
    ├── ocirepository.yaml
    └── externalsecret.yaml          # only if app needs secrets
    # If configMapGenerator pattern:
    └── resources/
        ├── {app}-config.yaml        # config template
        └── kustomizeconfig.yaml     # nameReference for ESO templateFrom
```

#### File templates

Use these exact patterns. All templates use YAML anchors (`&app` / `*app`) per repo convention.

---

##### ks.yaml

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/kustomization-kustomize-v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app {APP_NAME}
spec:
  # components — include based on feature selections:
  #   ../../../../components/volsync          (if volsync)
  #   ../../../../components/cnpg             (if cnpg)
  #   ../../../../components/ext-auth-internal (if forward-auth internal)
  #   ../../../../components/ext-auth-external (if forward-auth external)
  #   ../../../../components/keda/nfs-scaler   (if keda-nfs)
  #   ../../../../components/keda/nfs-bkup-scaler (if keda-nfs-backup)
  components: []  # populate from selections

  dependsOn:
    - name: secret-stores
      namespace: external-secrets
    # Add conditionally:
    #   cnpg-cluster / database        (if cnpg, CNPG_NAME=pgsql-cluster)
    #   cnpg-immich17 / database       (if cnpg with immich17 cluster — rare)
    #   rook-ceph-cluster / rook-ceph  (if volsync)
    #   volsync / volsync-system       (if volsync)
    #   keda / observability           (if any keda scaler)

  interval: 1h
  path: ./kubernetes/apps/{NAMESPACE}/{APP_NAME}/app
  postBuild:
    substitute:
      APP: *app
      # If GATUS_SUBDOMAIN differs from app name:
      GATUS_SUBDOMAIN: {SUBDOMAIN}
      # If health check path is not /:
      GATUS_PATH: {HEALTH_PATH}
      # If cnpg:
      CNPG_NAME: &postgresAppName pgsql-cluster
      # If volsync:
      VOLSYNC_CAPACITY: {CAPACITY}
    substituteFrom:
      - kind: Secret
        name: cluster-secrets

  # If cnpg — add healthChecks + healthCheckExprs:
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

  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: {NAMESPACE}
  wait: false
```

**Rules:**
- Only include `components`, `dependsOn`, `healthChecks`, `healthCheckExprs`, and `postBuild.substitute` entries that are relevant to the selected features.
- If GATUS_SUBDOMAIN equals the app name, omit it (the HR will use `{{ .Release.Name }}.${SECRET_DOMAIN}`).
- If GATUS_SUBDOMAIN differs from app name, include it and use `${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}` in the HR route.
- `wait: false` for apps, `wait: true` only for infrastructure dependencies.

---

##### app/ocirepository.yaml

**App-template:**
```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: {APP_NAME}
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: 4.6.2
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

**Custom chart:**
```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: {APP_NAME}
spec:
  interval: 1h
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: {CHART_VERSION}
  url: oci://{CHART_OCI_URL}
```

**Note:** For app-template, always check the latest tag in use across the repo. Run: `grep -h 'tag:' kubernetes/apps/default/homebox/app/ocirepository.yaml` to get the current version.

---

##### app/kustomization.yaml

**Standard (no configMapGenerator):**
```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./externalsecret.yaml    # only if ESO needed
  - ./helmrelease.yaml
  - ./ocirepository.yaml
```

**With configMapGenerator (immich pattern):**
```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - ./externalsecret.yaml
  - ./helmrelease.yaml
  - ./ocirepository.yaml
configMapGenerator:
  - name: {APP_NAME}-config-tpl
    files:
      - ./resources/{APP_NAME}-config.yaml
configurations:
  - ./resources/kustomizeconfig.yaml
generatorOptions:
  disableNameSuffixHash: true
```

**Important:** When using configMapGenerator, the kustomization `kind` changes from `Kustomization` to `Component` and the apiVersion changes to `v1alpha1`.

---

##### app/helmrelease.yaml (app-template)

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app {APP_NAME}
spec:
  chartRef:
    kind: OCIRepository
    name: *app
  interval: 1h
  values:
    controllers:
      *app :
        annotations:
          reloader.stakater.com/auto: "true"
        # If cnpg — add initContainers:
        initContainers:
          01-init-db:
            image:
              repository: ghcr.io/home-operations/postgres-init
              tag: 18.3.0@sha256:6fa1f331cddd2eb0b6afa7b8d3685c864127a81ab01c3d9400bc3ff5263a51cf  # check latest in repo
            envFrom:
              - secretRef:
                  name: "{{ .Release.Name }}-initdb-secret"
        containers:
          app:
            image:
              repository: {IMAGE_REPO}
              tag: {IMAGE_TAG}@{SHA256}  # always pin tag + sha digest
            env:
              TZ: ${TIMEZONE:-UTC}
              # App-specific env vars here
            envFrom:
              - secretRef:
                  name: "{{ .Release.Name }}-secret"
            resources:
              requests:
                cpu: 20m
                memory: 128Mi
              limits:
                memory: 512Mi
            probes:
              liveness: &probes
                enabled: true
                custom: true
                spec: &probeSpec
                  httpGet:
                    path: {HEALTH_PATH}
                    port: &port {APP_PORT}
                  periodSeconds: 30
                  timeoutSeconds: 5
                  failureThreshold: 5
              readiness:
                <<: *probes
                spec:
                  <<: *probeSpec
                  periodSeconds: 10
              startup:
                enabled: true
                spec:
                  failureThreshold: 30
                  periodSeconds: 10
            securityContext: &securityContext
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: { drop: [ALL] }
    # NOTE: These are ideal restrictive defaults. Some apps require root or
    # writable root filesystem. If the app fails to start, try:
    #   - readOnlyRootFilesystem: false
    #   - runAsNonRoot: false / runAsUser: 0
    #   - Add specific capabilities back (e.g. NET_BIND_SERVICE)
    # Only relax the minimum needed — don't blanket-disable everything.
    defaultPodOptions:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
    service:
      app:
        controller: *app
        ports:
          http:
            port: *port
    # Route section — only if ingress is not "None"
    # GATUS placement depends on auth method:
    #   - NO ext-auth: gatus annotation on the route (default)
    #   - WITH ext-auth (forward auth): gatus on the SERVICE, disabled on the route
    #     (ext-auth blocks gatus probes; envoy.yaml handles the health check)

    # --- Default (no ext-auth): gatus on route ---
    route:
      app:
        hostnames: ["${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}"]
        # OR if subdomain == app name:
        # hostnames: ["{{ .Release.Name }}.${SECRET_DOMAIN}"]
        parentRefs:
          - name: envoy-internal    # or envoy-external
            namespace: network
        rules:
          - backendRefs:
              - identifier: app
                port: *port

    # --- With ext-auth: gatus on service, disabled on route (see bazarr) ---
    # service:
    #   app:
    #     controller: *app
    #     ports:
    #       http:
    #         port: *port
    #     annotations:
    #       gatus.home-operations.com/enabled: "true"
    #       gatus.home-operations.com/endpoint: |
    #         group: "services"
    # route:
    #   app:
    #     hostnames: ["{{ .Release.Name }}.${SECRET_DOMAIN}"]
    #     annotations:
    #       gatus.home-operations.com/enabled: "false"
    #     parentRefs:
    #       - name: envoy-internal
    #         namespace: network
    #     rules:
    #       - backendRefs:
    #           - identifier: app
    #             port: *port
    persistence:
      # If volsync — existing PVC claim:
      config:
        existingClaim: *app
        globalMounts:
          - path: /data     # adjust mount path
      # Common ephemeral mounts:
      tmp:
        type: emptyDir
```

**Rules for the HelmRelease:**
- Only include `initContainers` block if CNPG is selected.
- Only include `envFrom` secretRef if the app has an ExternalSecret.
- Only include `route` section if ingress is not "None".
- Use `envoy-internal` or `envoy-external` based on ingress selection.
- If GATUS_SUBDOMAIN is custom (differs from app name): use `${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}` in hostnames.
- If GATUS_SUBDOMAIN equals app name: use `{{ .Release.Name }}.${SECRET_DOMAIN}` in hostnames and omit GATUS_SUBDOMAIN from ks.yaml substitute.
- **Gatus + ext-auth**: When the app uses ext-auth (forward auth), gatus probes are blocked by the auth layer. Move the gatus annotation to the **service** (with `enabled: "true"`) and add `gatus.home-operations.com/enabled: "false"` to the **route** annotations. See bazarr for the reference pattern.
- **Gatus without ext-auth**: No action needed, envoy handles the annotations.
- **Image tags**: Always pin with `tag@sha256:digest`. Leave `{IMAGE_REPO}` and `{IMAGE_TAG}@{SHA256}` as TODO placeholders with a Renovate annotation comment — the user will fill these in.
- **Security context**: Default restrictive. Note in a comment that some apps need relaxed settings (see template above).

---

##### app/externalsecret.yaml

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: &name {APP_NAME}-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: akeyless-secret-store
  target:
    name: *name
    template:
      data: {}
        # TODO: Map aKeyless secret keys to env var names
        # Example:
        # API_KEY: "{{ .APP_API_KEY }}"
  dataFrom:
    - extract:
        key: /{AKEYLESS_PATH}   # TODO: aKeyless secret path
```

**If OIDC auth is selected**, add Authentik-specific entries:
```yaml
  target:
    name: *name
    template:
      data:
        # OIDC configuration — adjust env var names per app docs
        OIDC_ISSUER_URL: "https://{{ .AUTHENTIK_SSO_SUBDOMAIN }}.${SECRET_DOMAIN}/application/o/${APP}/"
        OIDC_CLIENT_ID: "{{ .{APP_UPPER}_OIDC_CLIENT_ID }}"
        OIDC_CLIENT_SECRET: "{{ .{APP_UPPER}_OIDC_SECRET }}"
  dataFrom:
    - extract:
        key: /authentik
    - extract:
        key: /{APP_NAME}   # app-specific secrets
```

**If CNPG is selected**, template the DB connection vars directly in the app's ExternalSecret (homebox pattern — preferred approach). Add `/cnpg-users` to `dataFrom` and map individual vars in `target.template.data`:
```yaml
  target:
    template:
      data:
        # Adjust env var names to match what the app expects
        DATABASE_HOST: "${CNPG_NAME:=pgsql-cluster}-rw.database.svc.cluster.local"
        DATABASE_PORT: "5432"
        DATABASE_NAME: "${APP}"
        DATABASE_USER: "${APP}"
        DATABASE_PASSWORD: "{{ .${APP}_postgres_password }}"
  dataFrom:
    - extract:
        key: /cnpg-users
```

If the app supports a single connection URI (e.g. gatus `DB_URI`), build it in the template:
```yaml
        DB_URI: "postgres://{{ .${APP}_postgres_password }}@${CNPG_NAME:=pgsql-cluster}-rw.database.svc.cluster.local:5432/${APP}?sslmode=disable"
```

---

##### app/resources/kustomizeconfig.yaml (only with configMapGenerator)

```yaml
---
nameReference:
  - kind: ConfigMap
    version: v1
    fieldSpecs:
      - path: spec/target/template/templateFrom/configMap/name
        kind: ExternalSecret
```

---

##### app/resources/{app}-config.yaml (only with configMapGenerator)

Create a placeholder config file with a TODO comment. The user will populate this with the app's actual config. This file supports Go template syntax because it's processed through the ExternalSecret templateFrom mechanism.

---

### Phase 3 — Register the App

After generating all manifests:

1. **Add to namespace kustomization**: Append `- ./{APP_NAME}/ks.yaml` to `kubernetes/apps/{NAMESPACE}/kustomization.yaml` under `resources:`. Keep alphabetical order.

2. **Print summary**: List all created files and a short description of what was configured.

3. **Print next steps**:
   - Add secrets to aKeyless at the path referenced in externalsecret.yaml
   - Fill in `{IMAGE_REPO}` and `{IMAGE_TAG}` in helmrelease.yaml (add Renovate annotation)
   - Fill in ExternalSecret template data mappings
   - If configMapGenerator: populate the config file in resources/
   - If custom chart: verify the OCI URL and chart version
   - Test: `just kube apply-ks {NAMESPACE} {APP_NAME}`
   - Push and reconcile: `just kube ks-reconcile {NAMESPACE} {APP_NAME}`

## Important Notes

- **Never create a namespace.yaml** — namespaces already exist, managed by the namespace kustomization.
- **app-template version**: Before generating, grep the repo for the current app-template tag: check any existing app's ocirepository.yaml that references `bjw-s-labs/helm/app-template`.
- **postgres-init version**: Before generating, grep for the current `home-operations/postgres-init` tag in any existing helmrelease with initContainers.
- **Renovate annotations**: Add `# renovate: datasource=docker depName=...` comments on image tags so Renovate can auto-update them.
- **YAML anchors**: Always use `name: &app {name}` and reference as `*app` throughout.
- **Security context**: Default to restrictive (`readOnlyRootFilesystem: true`, drop ALL capabilities). Only relax if the app requires it.
- **Storage**: Default PVC storage class is `ceph-ssd` (handled by volsync component defaults). Only override for `openebs-hostpath` or `nfs-media` if needed.
