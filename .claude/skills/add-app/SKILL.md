---
name: add-app
description: Scaffold a new Kubernetes app in the home-ops monorepo. Prompts for app name, namespace, helm chart type, and optional features (volsync, cnpg, auth, keda, gatus, ESO, configMapGenerator, ingress). Generates all manifests following repo conventions.
---

# Add App Skill

Interactive scaffold for adding a new Flux-managed Kubernetes app to this monorepo.

## Workflow

### Phase 1 — Gather Inputs

Use `AskUserQuestion` to collect the following. Ask up to 4 questions per call, batch logically.
**Important**: Always ask all batches. Never infer or skip a batch based on arguments passed to the skill — the user must explicitly confirm each choice.

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

**Batch 3 — Features (multi-select, always ask):**

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

**Batch 5 — Gatus & Config details (conditional — only ask if ingress is NOT "None"):**

7. **Gatus subdomain**: What subdomain should this app be accessible at?
   - `Same as app name (Recommended)` — e.g. `{APP_NAME}.domain.com`
   - Other — let them type a custom/shortened subdomain

8. **Health check path**: What path should be used for liveness probes and Gatus?
   - `/ (default)` — root path
   - Other — let them type a custom path (e.g. `/healthz`, `/api/v1/ping`)

9. **Config style** (only if app-template):
   - `Inline env vars only` (Recommended) — all config via env vars in HelmRelease
   - `ConfigMapGenerator + ESO` — external config file templated with secrets (like immich pattern: configMapGenerator in kustomization.yaml + kustomizeconfig.yaml + ExternalSecret templateFrom)

### Phase 2 — Research Before Generating

Before writing any files, gather the following from the repo:

1. **app-template version**: `grep -h 'tag:' kubernetes/apps/default/homebox/app/ocirepository.yaml`
2. **postgres-init version** (if CNPG selected): `grep -rh 'postgres-init' kubernetes/apps/ --include='*.yaml' -A1 | grep 'tag:' | head -1`
3. **Existing secret patterns** (if the user mentioned any shared/external service — e.g. Amazon SES, SMTP, S3, Cloudflare): grep the repo for an existing app known to use that service. For example, if SES/email is requested, check `kubernetes/apps/default/mealie/app/externalsecret.yaml` for the exact aKeyless key names and env var mappings already in use. Use matching key names in the new ExternalSecret — do not invent new names.

### Phase 3 — Generate Manifests

After collecting inputs and completing research, generate all files. Write each file using the Write tool. **Do not return file contents inline.**

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
**No extra blank lines** between YAML sections — keep output compact.

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
  components:
    - ../../../../components/cnpg                 # if cnpg selected
    - ../../../../components/volsync              # if volsync selected
    - ../../../../components/ext-auth-internal    # if forward-auth internal
    - ../../../../components/ext-auth-external    # if forward-auth external
    - ../../../../components/keda/nfs-scaler      # if keda-nfs selected
    - ../../../../components/keda/nfs-bkup-scaler # if keda-nfs-backup selected
  dependsOn:
    - name: secret-stores
      namespace: external-secrets
    - name: cnpg-cluster          # if cnpg (CNPG_NAME=pgsql-cluster)
      namespace: database
    - name: rook-ceph-cluster     # if volsync
      namespace: rook-ceph
    - name: volsync               # if volsync
      namespace: volsync-system
    - name: keda                  # if any keda scaler
      namespace: observability
  interval: 1h
  path: ./kubernetes/apps/{NAMESPACE}/{APP_NAME}/app
  postBuild:
    substitute:
      APP: *app
      GATUS_SUBDOMAIN: {SUBDOMAIN}       # omit if subdomain == app name
      CNPG_NAME: &postgresAppName pgsql-cluster  # if cnpg
      VOLSYNC_CAPACITY: {CAPACITY}       # if volsync
    substituteFrom:
      - kind: Secret
        name: cluster-secrets
  healthChecks:                          # if cnpg
    - apiVersion: &postgresVersion postgresql.cnpg.io/v1
      kind: &postgresKind Cluster
      name: *postgresAppName
      namespace: database
  healthCheckExprs:                      # if cnpg
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
  name: &app {APP_NAME}
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: {CURRENT_APP_TEMPLATE_TAG}
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
        initContainers:              # only if cnpg selected
          01-init-db:
            image:
              repository: ghcr.io/home-operations/postgres-init
              tag: {CURRENT_POSTGRES_INIT_TAG}
            envFrom:
              - secretRef:
                  name: "{{ .Release.Name }}-initdb-secret"
        containers:
          app:
            image:
              repository: {IMAGE_REPO}   # TODO: fill in image repository
              tag: latest                # TODO: replace with pinned tag@sha256 digest
            env:
              TZ: ${TIMEZONE:-UTC}
              # TODO: add app-specific env vars
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
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: { drop: [ALL] }
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
    route:                           # only if ingress is not "None"
      app:
        hostnames: ["{{ .Release.Name }}.${SECRET_DOMAIN}"]
        # OR if custom subdomain: ["${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}"]
        parentRefs:
          - name: envoy-internal     # or envoy-external
            namespace: network
        rules:
          - backendRefs:
              - identifier: app
                port: *port
    persistence:
      config:                        # only if volsync selected
        existingClaim: *app
        globalMounts:
          - path: /data              # TODO: verify app data directory path
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
- **Image tags**: Leave `{IMAGE_REPO}` and a `TODO` tag as placeholders — the user will fill these in.
- **Security context**: Default to restrictive (`readOnlyRootFilesystem: true`, drop ALL capabilities). If an app fails to start due to security context, that is follow-up troubleshooting — do not pre-emptively add comments or relaxed settings.
- **No extra blank lines** between YAML sections.

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
        # TODO: verify exact env var names per app docs
        OIDC_ISSUER_URL: "https://{{ .AUTHENTIK_SSO_SUBDOMAIN }}.${SECRET_DOMAIN}/application/o/${APP}/"
        OIDC_CLIENT_ID: "{{ .{APP_UPPER}_OIDC_CLIENT_ID }}"
        OIDC_CLIENT_SECRET: "{{ .{APP_UPPER}_OIDC_SECRET }}"
  dataFrom:
    - extract:
        key: /authentik
    - extract:
        key: /{APP_NAME}
```

**If CNPG is selected**, template the DB connection vars directly in the app's ExternalSecret (homebox pattern — preferred approach). Add `/cnpg-users` to `dataFrom` and map individual vars in `target.template.data`:
```yaml
  target:
    template:
      data:
        # TODO: verify DB env var names per app docs
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

**If shared/external service secrets are requested** (e.g. Amazon SES, SMTP, S3, Cloudflare): use the exact aKeyless key names and env var mappings already established in the repo. Reference was already looked up in Phase 2 research — do not invent new key names.

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

### Phase 4 — Register the App

After generating all manifests:

1. **Add to namespace kustomization**: Append `- ./{APP_NAME}/ks.yaml` to `kubernetes/apps/{NAMESPACE}/kustomization.yaml` under `resources:`. Keep alphabetical order.

2. **Print summary**: List all created files and a short description of what was configured.

3. **Print next steps**:
   - Add secrets to aKeyless at the path referenced in externalsecret.yaml
   - Fill in `{IMAGE_REPO}` and `{IMAGE_TAG}` in helmrelease.yaml
   - Fill in ExternalSecret template data mappings
   - If configMapGenerator: populate the config file in resources/
   - If custom chart: verify the OCI URL and chart version
   - Test: `just kube apply-ks {NAMESPACE} {APP_NAME}`
   - Push and reconcile: `just kube ks-reconcile {NAMESPACE} {APP_NAME}`

## Important Notes

- **Never create a namespace.yaml** — namespaces already exist, managed by the namespace kustomization.
- **app-template version**: Always grep the repo for the current tag before generating (see Phase 2).
- **postgres-init version**: Always grep the repo for the current tag before generating (see Phase 2).
- **No Renovate annotations**: Do not add `# renovate:` comments to image tags — Renovate config handles discovery automatically.
- **YAML anchors**: Always use `name: &app {name}` and reference as `*app` throughout.
- **Security context**: Default to restrictive (`readOnlyRootFilesystem: true`, drop ALL capabilities). Do not add comments about relaxing these — that is follow-up troubleshooting if needed.
- **Storage**: Default PVC storage class is `ceph-ssd` (handled by volsync component defaults). Only override for `openebs-hostpath` or `nfs-media` if needed.
- **No extra blank lines**: Keep YAML output compact — no unnecessary blank lines between sections.
