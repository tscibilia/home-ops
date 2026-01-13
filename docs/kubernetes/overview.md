# Kubernetes Layer Overview

Applications live in `kubernetes/` and are deployed via Flux CD (GitOps). Edit YAML under `kubernetes/apps/`, push to GitHub, and Flux reconciles (hourly by default). Manual cluster edits are reverted to Git.

## How GitOps Is Used

```mermaid
graph LR
  A[Push to GitHub] --> B[Flux Detects Change]
  B --> C[Flux Reconciles]
  C --> D[Cluster Updated]
```

1. You edit YAML files in [`kubernetes/apps/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps)
2. Commit and push to GitHub
3. Flux detects the change (polls every hour, or you can force it)
4. Flux applies the changes to the cluster

If a configuration is manually edited in the cluster, Flux will revert it back to match Git. This prevents drift and ensures Git is always the source of truth.

## Directory structure

Applications are grouped by namespace under `kubernetes/apps/`. Reusable components live in `kubernetes/components/` and Flux bootstrap config is in `kubernetes/flux/`.

Example layout:

```
kubernetes/
├── apps/                    # All applications
│   ├── default/            # Main apps (Authentik, Immich, etc.)
│   ├── media/              # Media stack (Plex, Sonarr, etc.)
│   ├── database/           # Database layer (CNPG, Dragonfly)
│   ├── network/            # Networking (Envoy, Cloudflared)
│   ├── observability/      # Monitoring (Grafana, VictoriaMetrics)
│   ├── kube-system/        # Core K8s components (Cilium, CoreDNS)
│   ├── rook-ceph/          # Storage backend
│   ├── external-secrets/   # Secrets management
│   └── ...                 # Other namespaces
├── components/             # Reusable Kustomize components
│   ├── cnpg/              # Database provisioning
│   ├── ext-auth-external/ # Authentik SSO (external gateway)
│   ├── ext-auth-internal/ # Authentik SSO (internal gateway)
│   ├── volsync/           # Backup/restore
│   ├── keda/              # Auto-scaling configs
│   └── common/            # Alerts and secrets
└── flux/                  # Flux CD bootstrap config
```

## Application Structure Pattern

Every app follows the same structure. Let's look at Authentik as an example:

```
kubernetes/apps/default/authentik/
├── ks.yaml                 # Flux Kustomization (orchestrates everything)
├── app/
│   ├── kustomization.yaml  # Kustomize resources list
│   ├── helmrelease.yaml    # Helm chart configuration
│   ├── ocirepository.yaml  # Where to fetch the chart from
│   ├── externalsecret.yaml # Secrets from aKeyless
│   └── resources/          # Additional resources (optional)
├── outposts/               # Authentik-specific: outpost deployments
└── namespace.yaml          # Namespace definition
```

Keep app configs minimal and use components for shared behavior (DB provisioning, auth, backups). The `ks.yaml` healthChecks and `dependsOn` prevent apps from deploying before their dependencies are ready.

## Reusable Components

Located in [`kubernetes/components/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components), these are DRY configurations applied to multiple apps.

### CNPG Component

From [`kubernetes/components/cnpg/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components/cnpg):

- Creates a database user for the app
- Generates a secret with `username`, `password`, `uri`
- Runs a CronJob to initialize the database

Apps using PostgreSQL include this component in their `ks.yaml`.

### External Auth Components

Two variants for different gateways:

- **`ext-auth-external`**: For apps exposed via `envoy-external` gateway (internet-facing)
- **`ext-auth-internal`**: For apps exposed via `envoy-internal` gateway (LAN-only)

Both create a SecurityPolicy that forwards authentication to Authentik's dedicated outpost deployments. Authentik uses separate outpost pods for external and internal gateways for better isolation and scaling.

See [`kubernetes/components/ext-auth-external/securitypolicy.yaml`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/components/ext-auth-external/securitypolicy.yaml):

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: "${APP}"
spec:
  extAuth:
    failOpen: false  # Deny if Authentik is down
    http:
      backendRefs:
        - name: authentik-outpost-external
          namespace: default
          port: 9000
      path: /outpost.goauthentik.io/auth/envoy
  targetRefs:
    - kind: HTTPRoute
      name: "${APP}"  # Protects the app's HTTPRoute
```

When an app includes this component, it automatically gets SSO protection through Authentik.

### VolSync Component

From [`kubernetes/components/volsync/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components/volsync):

- Creates a ReplicationSource (backs up to S3-compatible storage)
- Creates a ReplicationDestination (restores from backup)
- Manages Restic repository secrets

Apps with persistent data (like Immich, Home Assistant) include this for automatic backups.

??? info "How VolSync Works"
    VolSync takes snapshots of PersistentVolumeClaims and uploads them to cloud storage (Backblaze B2 in this cluster). Snapshots run on a schedule (defined in `replicationsource.yaml`).

    To restore, you create a new PVC with a `dataSourceRef` pointing to the ReplicationDestination, and Kubernetes populates it from the latest backup.

    See [Storage Guide](storage.md#volsync-backups) for details.

### KEDA Components

From [`kubernetes/components/keda/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/components/keda):

- **`nfs-scaler`**: Scales apps down when NFS is unavailable
- **`nfs-bkup-scaler`**: Scales apps down when backup NFS is unavailable

These prevent apps from crashing when their storage disappears (e.g., during NAS maintenance).

## Flux Reconciliation Loop

Flux continuously reconciles cluster state:

```mermaid
graph TB
    A[GitRepository] --> B[Kustomization]
    B --> C[HelmRelease]
    C --> D[Kubernetes Resources]

    D -->|Drift detected| B
    B -->|Reapply| D
```

1. **GitRepository**: Flux clones the Git repo and watches for commits
2. **Kustomization** (Flux CRD): Reads `ks.yaml`, applies dependencies, substitutes variables
3. **HelmRelease**: Flux renders the Helm chart and applies it
4. **Resources**: Deployments, Services, etc. get created in the cluster
5. **Drift Detection**: If someone runs `kubectl edit` manually, Flux reverts it back to match Git

## Dependency Management

Apps declare dependencies in their `ks.yaml`:

```yaml
dependsOn:
  - name: cnpg-cluster
    namespace: database
  - name: secret-stores
    namespace: external-secrets
```

Flux ensures dependencies are Ready before deploying the app. This prevents errors like:

- Deploying an app before its database exists
- Referencing ExternalSecrets before the operator is running
- Creating an HTTPRoute before Envoy Gateway is installed

??? example "Real Dependency Chain"
    Here's how Authentik's dependencies flow:

    ```
    external-secrets (operator)
    └── secret-stores (ClusterSecretStore)
        └── cnpg-cluster (PostgreSQL operator + cluster)
            └── authentik (app)
                └── authentik-outposts (embedded outpost)
    ```

    Each level waits for the previous to be healthy before deploying.

## Variable Substitution

Flux supports variable substitution via `postBuild.substitute`:

```yaml
postBuild:
  substitute:
    APP: authentik
    GATUS_SUBDOMAIN: auth
    CNPG_NAME: pgsql-cluster
  substituteFrom:
    - kind: Secret
      name: cluster-secrets
```

In your YAML files, use `${APP}` and it gets replaced with `authentik`. The `cluster-secrets` Secret contains cluster-wide variables like domain names, IP ranges, etc.

??? tip "Common Substitution Variables"
    From `cluster-secrets` (values injected from aKeyless):

    - `${SECRET_DOMAIN}`: Your main domain (e.g., `t0m.co`)
    - `${CLUSTER_NAME}`: Cluster name (`main`)
    - `${SECRET_CLOUDFLARE_TUNNEL_ID}`: Cloudflare tunnel ID
    - App-specific secrets like API keys, tokens, etc.

## Next Steps

Explore specific topics:

- [**Applications**](applications.md): How to add, update, and manage apps
- [**Networking**](networking.md): How traffic flows through the cluster
- [**Storage**](storage.md): Persistent storage and backups
- [**Secrets**](secrets.md): Managing sensitive data

??? info "Want more context?"
    Check out the [DeepWiki Kubernetes section](https://deepwiki.com/tscibilia/home-ops?tab=kubernetes) for AI-generated insights into the app structure.
