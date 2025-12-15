# Copilot Instructions for home-ops

This is a **Kubernetes-based home infrastructure monorepo** managed with Flux CD, Talos OS, and Helm. The architecture separates concerns into Talos (node management), Kubernetes manifests (apps), and Infrastructure as Code patterns.

**📋 Before reading:** Check [`copilot-activework.md`](./copilot-activework.md) for current development initiatives, known issues, and blocked work. This document covers architecture & patterns; the active work doc covers current momentum.

## Architecture Overview

**Three-layer stack:**
1. **Talos** (`/talos`): Immutable Linux OS with Kubernetes pre-installed. Generated from minijinja templates (`machineconfig.yaml.j2` and node patches `nodes/*.yaml.j2`), includes node-specific patches and sops-encrypted secrets.
2. **Kubernetes** (`/kubernetes`): Flux-driven GitOps. Apps organized by namespace in `/kubernetes/apps/*/{namespace}/{app-name}/`.
3. **Bootstrap** (`/bootstrap`): Helmfile deployment for initial cluster setup (cilium, coredns, spegel, cert-manager, external-secrets).

## Task Runner Usage

Commands via `just` (main `.justfile` with 3 modules from `bootstrap`, `kubernetes`, and `talos`):

### Bootstrap Module (`just bootstrap`)
**Cluster Installation & Setup:**
- `talos` - Install Talos on all configured nodes
- `k8s` - Bootstrap Kubernetes cluster
- `kubeconfig [lb]` - Fetch kubeconfig (optional: set load balancer, default: cilium)
- `wait` - Wait for nodes to be ready
- `namespaces` - Apply all Kubernetes namespaces
- `resources` - Apply Kubernetes resources from templates (uses akeyless-inject)
- `crds` - Apply CRDs from Helmfile
- `apps` - Sync all apps from Helmfile
- `default` - Run full bootstrap sequence (all stages above)

### Kubernetes Module (`just kube`)
**Resource Management:**
- `browse-pvc <namespace> <claim>` - Mount PVC to debug pod for inspection
- `node-shell <node>` - Open interactive shell on a node
- `prune-pods` - Delete all pods in Failed, Pending, or Succeeded state
- `view-secret <namespace> <secret>` - View decoded secret contents

**Flux Operations:**
- `sync-git` - Sync all GitRepositories (force reconcile)
- `sync-oci` - Sync all OCIRepositories (force reconcile)
- `sync-es <ns> <name>` - Force sync a single ExternalSecret
- `sync-hr <ns> <name>` - Force sync a single HelmRelease
- `sync-ks <ns> <name>` - Force sync a single Kustomization
- `sync-all-es` - Sync all ExternalSecrets across cluster
- `sync-all-hr` - Sync all HelmReleases across cluster
- `sync-all-ks` - Sync all Kustomizations across cluster
- `ks-restart` - Restart all failed Kustomizations (suspend/resume)
- `hr-restart` - Restart all failed HelmReleases (suspend/resume)
- `ks-reconcile <ns> <name>` - Force Kustomization reconcile from source
- `hr-reconcile <ns> <name>` - Force HelmRelease reconcile from source
- `ks-reconcile-all` - Force all Kustomizations to reconcile from source
- `hr-reconcile-all` - Force all HelmReleases to reconcile from source
- `apply-ks <ns> <ks>` - Apply local Kustomization (using flux-local)
- `delete-ks <ns> <ks>` - Delete local Kustomization

**VolSync Backups:**
- `snapshot <ns> <name>` - Trigger manual snapshot for single PVC
- `snapshot-all` - Trigger snapshots for all VolSync PVCs
- `volsync <state>` - Suspend or resume VolSync (state: suspend/resume)
- `volsync-unlock` - Unlock all restic repositories
- `volsync-list <ns> <name>` - List available snapshots for app
- `volsync-restore <ns> <name> <previous>` - Restore from backup snapshot

**KEDA Auto-scaling:**
- `keda <state> <ns> <name>` - Suspend or resume ScaledObject (state: suspend/resume)
- `keda-all <state>` - Suspend or resume all ScaledObjects

**Network Stack:**
- `restart-network` - Restart network components in dependency order (CoreDNS → Cilium → Cloudflared → External-DNS → unifi-dns → Envoy)

### Talos Module (`just talos`)
**Node Management:**
- `apply-node <node> [args]` - Apply Talos config to specific node
- `render-config <node>` - Render Talos config for node (with patches)
- `reboot-node <node>` - Reboot node with confirmation
- `shutdown-node <node>` - Shutdown node with confirmation
- `reset-node <node>` - Factory reset node with confirmation

**Upgrades & Images:**
- `upgrade-k8s <version>` - Upgrade Kubernetes version on cluster
- `upgrade-node <node>` - Upgrade Talos version on node
- `download-image <version> <schematic>` - Download Talos ISO image
- `gen-schematic-id` - Generate schematic ID from template

**Common Patterns:**
- All commands check for required tools (talosctl, kubectl, flux, etc.) before execution
- Interactive operations (reboot, reset, shutdown) require confirmation via gum
- Template-based configs support variable injection via minijinja and akeyless

## App Structure Pattern

Each app follows a strict directory structure:
```
kubernetes/apps/{namespace}/{app-name}/
├── ks.yaml                  # Flux Kustomization (links to ./app, sets dependencies, postBuild substitutions)
├── app/
│   ├── kustomization.yaml   # Kustomize configuration (resources, configMapGenerator, patches)
│   ├── helmrelease.yaml     # HelmRelease spec (chart ref, values, interval)
│   ├── ocirepository.yaml   # OCIRepository for Helm chart source
│   ├── externalsecret.yaml  # External Secrets integration (aKeyless)
│   ├── referencegrant.yaml  # Cross-namespace networking permissions
│   └── resources/           # Kustomize patches, configs, custom resources
└── namespace.yaml           # Namespace definition
```

**Key pattern:** `ks.yaml` (Flux Kustomization) delegates to `app/kustomization.yaml` (Kustomize). The `ks.yaml` defines:
- Helm chart source via `components` (e.g., `../../../../components/cnpg`)
- Use `dependsOn` to ensure proper deployment order
- Use `postBuild.substitute` for variable substitution (e.g., `APP`, `GATUS_SUBDOMAIN`)
- Use `postBuild.substituteFrom` to reference secrets (commonly `cluster-secrets`)
- Use health checks for CRD-dependent resources

## Storage & Data Management

**Storage Classes:**
- **openebs-hostpath**: Local ephemeral storage (openebs)
- **ceph-ssd**: Persistent block storage (rook-ceph)
- **cephfs**: Shared filesystem storage (rook-ceph)
- **nfs-media**: Network shared filesystem (nfs)

**VolSync Backups:**
VolSync (`volsync-system` namespace) provides automated backup/restore for stateful apps using Restic:
- Deployed via `volsync/` Kustomize component in app's `ks.yaml` (examples: home-assistant, immich database)
- Requires postBuild substitutions: `VOLSYNC_CAPACITY` (PVC size), `APP` (app name)
- Snapshot CRD defines backup schedule, ReplicationDestination handles data transfer to cloud storage
- Restores via Volume Populator: new PVC with `dataSourceRef` auto-populates from latest backup
- Requires `RESTIC_PASSWORD` and cloud storage credentials (B2, S3, etc.) managed via aKeyless
- **Commands:** See [Task Runner Usage](#task-runner-usage) section for all VolSync commands (snapshot, restore, list, unlock)

## Cluster Networking Architecture

**CNI & Load Balancing (Cilium):**
- Cilium replaces kube-proxy with eBPF-based networking (kubeProxyReplacement enabled)
- Native routing mode with L2 announcements to expose services on home LAN (192.168.5.0/24)
- LoadBalancer algorithm uses Maglev with DSR (Direct Server Return) for performance
- CiliumLoadBalancerIPPool allocates IPs from home network range; CiliumL2AnnouncementPolicy advertises them via ARP

**DNS & Service Discovery (Split DNS):**
- **CoreDNS**: Internal cluster DNS (10.43.0.10) handles *.cluster.local and resolves via /etc/resolv.conf fallthrough
- **unifi-dns**: external-dns deployment with UniFi webhook provider syncs DNS records from Kubernetes to UniFi Controller
  - Watches HTTPRoute and Service resources for DNS changes
  - Automatically creates/updates/deletes DNS A records in UniFi controller based on Kubernetes resources
  - Integrated with Cloudflare Zero Trust DNS over HTTPS for enhanced security
  - Domain filter: `${SECRET_DOMAIN}` (t0m.co)
  - TXT record prefix: `k8s.main.` for ownership tracking
- **external-dns**: Syncs Gateway HTTPRoute resources to Cloudflare DNS, marking external-only routes as `--cloudflare-proxied`
  - Watches `envoy-external` gateway for routes to expose externally
  - Monitors CRDs (DNSEndpoint) and Gateway HTTPRoutes for updates

**External Access (Cloudflared Tunnel):**
- Cloudflared runs as a controller in network namespace, establishes QUIC tunnel to Cloudflare
- Configured via `config.yaml` to intercept `*.${SECRET_DOMAIN}` and route to `envoy-external.network.svc.cluster.local:443`
- Replaces traditional port-forwarding with Cloudflare's Zero Trust tunnel (no inbound firewall rules needed)
- Falls back to HTTP 404 for unregistered hostnames

**Ingress Gateway (Envoy Gateway):**
- `envoy-external`: Routes traffic from cloudflared tunnel, handles mTLS termination via cert-manager
- `envoy-internal`: (if present) Routes internal-only traffic
- Gateway resources define routing rules, SecurityPolicies enforce cross-namespace access (ReferenceGrant)
- HTTPRoute resources automatically synced by external-dns to update Cloudflare DNS

**Traffic Flow Summary:**
1. **Internal**: Pod → CoreDNS (10.43.0.10) → Cilium load balancer → Service pods
2. **Internal from LAN**: Client (192.168.5.0/24) → UniFi DNS → Cloudflare DoH → CoreDNS lookup → Cilium LB → Service
3. **External**: Internet → Cloudflare tunnel → cloudflared → envoy-external → Service pods

## Secrets Management

**aKeyless + ExternalSecrets + SOPS pattern:**
- External-facing secrets: Managed in aKeyless, synced via `ExternalSecret` CRDs
- Git-committed secrets: Encrypted with SOPS/Age key, stored as `*.sops.yaml` files
- Cluster bootstrap secrets: `cluster-secrets` ConfigMap injected via `postBuild.substituteFrom`
- Helm chart credentials: Encrypted in helmrelease values or via PullSecrets

**Commands:** See [Task Runner Usage](#task-runner-usage) section for ExternalSecret and secret management commands

## Critical Dependencies & Integration Points

**Flux system dependencies (bootstrap order in `/bootstrap/helmfile.d/01-apps.yaml`):**
1. cilium (CNI) → coredns → spegel (OCI mirror) → cert-manager → external-secrets

**App-level dependencies (defined in `ks.yaml`):**
- Database apps depend on `cnpg-cluster` (database namespace)
- Apps using secrets depend on `external-secrets` namespace
- Dragonfly cache dependencies for certain apps

**Example:** Authentik depends on pgsql-cluster CNPG cluster:
```yaml
dependsOn:
  - name: cnpg-cluster
    namespace: database
healthChecks:
  - apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    name: pgsql-cluster
```

## App Communication & Integration Patterns

**Service Discovery (DNS-based):**
Apps communicate internally via Kubernetes Service DNS: `<service-name>.<namespace>.svc.cluster.local`
- Database connections: `postgresql.default.svc.cluster.local` (from CNPG cluster)
- Cache layer: `dragonfly-cluster.database.svc.cluster.local:6379` (used by searxng, immich, etc.)
- Example from immich: `REDIS_HOSTNAME: dragonfly-cluster.database.svc.cluster.local`

**Shared Infrastructure (Database Tier):**
- **CNPG clusters** (PostgreSQL): Deployed in `database` namespace, apps depend via `dependsOn: cnpg-cluster`
  - Each app gets a Kubernetes Secret with `user`, `password`, `uri` keys (managed by CNPG/ExternalSecrets)
  - Referenced in HelmRelease: `valueFrom.secretKeyRef: immich-pguser-secret`
- **Dragonfly** (Redis): Deployed in `database` namespace, accessed via hardcoded environment variables
  - Apps allocate different database indices (immich uses 2, searxng uses 3) to avoid conflicts

**Cross-Namespace Service Access:**
- Secured via `ReferenceGrant` CRDs (gateway.networking.k8s.io/v1beta1)
- Example: authentik's embedded outpost service accessible to media, database, flux-system namespaces
- Use when apps in different namespaces need to reference services (e.g., SecurityPolicy referencing a Service)

**Reusable Components (DRY Pattern):**
Kustomize components in `/kubernetes/components/` provide shared configuration:
- `common/` - Standard alerts, secrets configuration applied to all namespaces
- `cnpg/` - Automatic database user initialization via CronJob and ExternalSecret
- `ext-auth-internal/` - Authentik SSO integration via SecurityPolicy for internal gateway (see Authentik SSO section)
- `ext-auth-external/` - Authentik SSO integration via SecurityPolicy for external gateway (see Authentik SSO section)
- `keda/` - Auto-scaling configuration via KEDA ScaledObjects
- `volsync/` - Backup/restore configuration (see Storage & Data Management section)
- Apps include via `components: [../../../../components/cnpg]` in `ks.yaml`

**Configuration Sharing via ConfigMaps:**
- `configMapGenerator` in `app/kustomization.yaml` embeds files (e.g., immich's `immich-config.yaml`, authentik's `custom.css`)
- Mounted in HelmRelease `volumeMounts` pointing to `/config`
- Example: immich references `IMMICH_CONFIG_FILE: /config/immich-config.yaml`

**External Service Integration:**
- Cloudflared tunnel (network namespace) exposes services via Cloudflare
- external-dns (network namespace) syncs Ingress DNS records to Cloudflare
- Services secured via cert-manager (TLS certificates)

## Authentik SSO & Forward Auth Pattern

**Architecture Overview:**
Authentik provides Single Sign-On (SSO) for the cluster using Envoy Gateway's forward authentication (ext-auth) plugin. Apps protected by Authentik include: qbittorrent, radarr, sonarr, prowlarr, bazarr, tautulli, spoolman, victoria-metrics.

**Key Components:**
1. **Authentik Server** (`default` namespace):
   - Main application deployed via HelmRelease with embedded outpost sidecar
   - Stores user credentials, application configurations, and policies in pgsql-cluster database
   - Exposes SSO interface at `/auth/` endpoint (e.g., `auth.t0m.co`)
   - Worker replicas (2x) handle background tasks and policy evaluation

2. **Authentik Embedded Outpost** (`default` namespace):
   - Sidecar container running in authentik pod (`ak-outpost-authentik-embedded-outpost` service on port 9000)
   - Handles forward authentication requests from Envoy Gateway
   - Validates user sessions, checks authorization policies, forwards authenticated headers

3. **ext-auth Components** (`/kubernetes/components/ext-auth-internal/` and `/kubernetes/components/ext-auth-external/`):
   - Kustomize components applied to apps that need SSO protection:
     - `ext-auth-internal`: For apps accessed via internal gateway (LAN access)
     - `ext-auth-external`: For apps accessed via external gateway (Cloudflare tunnel)
   - Defines Envoy Gateway SecurityPolicy CRD with ext-auth configuration:
     - Routes auth requests to `/outpost.goauthentik.io/auth/envoy` endpoint
     - Passes cookies and headers to Authentik for validation
     - Returns authenticated headers (set-cookie, x-authentik-*, authorization) back to client

4. **SecurityPolicy Integration:**
   - Uses ReferenceGrant to allow SecurityPolicy in network namespace to reference Services in default namespace
   - `failOpen: false` - Denies access if Authentik is unreachable (fail secure)
   - Targets HTTPRoute resources (apps' ingress routes) to enforce auth on specific routes
   - Example: Sonarr HTTPRoute (`media` namespace) protected by SecurityPolicy in `network` namespace via ext-auth

**How It Works (Request Flow):**
1. Client accesses `sonarr.t0m.co` (external) → Cloudflared → Envoy Gateway (`envoy-external`)
2. Envoy Gateway checks SecurityPolicy attached to sonarr HTTPRoute, sees ext-auth required
3. Before forwarding to sonarr service, Envoy calls Authentik outpost at `http://ak-outpost-authentik-embedded-outpost.default.svc.cluster.local:9000/outpost.goauthentik.io/auth/envoy`
4. Authentik validates session cookie (checks if user is logged in and authorized for Sonarr app)
5. If valid: forwards request with authenticated headers (x-authentik-*) to sonarr Pod
6. If invalid: redirects user to `https://auth.t0m.co/auth/` for login
7. After login, Authentik sets session cookie and redirects back to original app

**Adding SSO to a New App:**
1. Add `- ../../../../components/ext-auth-internal` or `- ../../../../components/ext-auth-external` to app's `ks.yaml` components list
   - Use `ext-auth-internal` for apps accessed only from LAN (media, observability)
   - Use `ext-auth-external` for apps accessed from internet via Cloudflare tunnel
2. Define HTTPRoute (Gateway routing rule) for the app in `app/helmrelease.yaml` or resources
3. Substitute `${APP}` in ks.yaml; component auto-creates SecurityPolicy targeting HTTPRoute by name
4. ReferenceGrant already permits: authentik's outpost accessible from network namespace SecurityPolicy

**Related Files:**
- Authentik deployment: `kubernetes/apps/default/authentik/`
- ext-auth-internal component: `kubernetes/components/ext-auth-internal/securitypolicy.yaml` (parameterized SecurityPolicy for internal gateway)
- ext-auth-external component: `kubernetes/components/ext-auth-external/securitypolicy.yaml` (parameterized SecurityPolicy for external gateway)
- Protected apps: `kubernetes/apps/media/{qbittorrent,radarr,sonarr,prowlarr,bazarr,tautulli}` (internal), `kubernetes/apps/media/ytptube` (external), and `kubernetes/apps/observability/{victoria-metrics,victoria-logs}` (internal)

## Flux Reconciliation & HelmRelease Management

**Key Patterns:**
- Flux controller continuously reconciles cluster state against Git repository
- Reconciliation interval: `interval: 1h` in `ks.yaml` (checks Git every hour)
- Direct flux CLI commands (suspend, resume) can be used alongside just commands
- See **Task Runner Usage** section below for all Flux sync, reconcile, and restart commands

**HelmRelease troubleshooting:**
If a HelmRelease is stuck: delete it to allow Flux to redeploy
```bash
kubectl delete helmrelease <name> -n <namespace>
just kube ks-reconcile <namespace> <name>
```

## GitOps Workflows: Flux & Renovate

**Flux CD (Declarative GitOps):**
- Flux controller continuously reconciles cluster state against Git repository
- Pull-based model: cluster watches Git for changes, applies them automatically
- Key resources: `GitRepository` (Git source), `Kustomization` (Flux), `HelmRelease` (Helm deployments)
- Reconciliation interval: `interval: 1h` in `ks.yaml` (checks Git every hour, can be forced with `flux reconcile`)
- Bootstrap via Helmfile (`/bootstrap/helmfile.d/`) deploys core components in correct dependency order

**Renovate (Dependency Automation):**
- Automated bot creates pull requests when new versions of images, Helm charts, or other dependencies are available
- Configuration in `.renovaterc.json5` with modular configs in `/.renovate/` directory
- Runs hourly via GitHub Actions (`.github/workflows/renovate.yaml`)
- Custom managers (`.renovate/customManagers.json5`) detect annotated dependencies:
  - `# renovate: datasource=docker depName=...` - Container images
  - `# renovate: datasource=helm repository=...` - Helm charts
  - OCI image references (`oci://...`) automatically detected
- Grouped updates: batch related upgrades (e.g., Authentik images together, Flux components together)
- Auto-merge enabled for minor/patch updates; major versions require approval

**Workflow Automation (GitHub Actions):**
- **flux-local.yaml**: On PR, validates Flux manifests (syntax, chart rendering, dependency checks)
  - Runs `flux-local test` to detect configuration errors before merge
  - Prevents broken deployments from entering main branch
- **renovate.yaml**: Scheduled bot creates/updates dependency upgrade PRs
  - Dry-run or full-run modes (manual trigger)
  - Semantic commits: `chore(deps): ...` for commit messages

**Key GitOps Patterns in home-ops:**
1. **Single source of truth**: All cluster state declared in Git (`/kubernetes/apps`)
2. **Declarative YAML**: Every app is `kubectl apply --dry-run=client` friendly
3. **Drift detection**: Flux automatically reverts manual changes back to Git state (via `prune: true`)
4. **Version pinning**: All Helm charts and images have explicit versions (renovate keeps them updated)
5. **Sealed secrets**: SOPS encryption for secrets committed to Git, automatic decryption by cluster

**Renovate Integration with this Cluster:**
- Image upgrades marked with `# renovate: datasource=docker` in `ks.yaml` or `helmrelease.yaml`
- Example: `kubernetes/apps/kube-system/cilium/app/helmrelease.yaml` tracks cilium updates
- Example: `kubernetes/apps/default/authentik/app/helmrelease.yaml` tracks authentik server+worker versions
- Renovate groups related updates (e.g., all authentik images in one PR, all Flux components in one PR)
- Ignores SOPS-encrypted files (`**/*.sops.*`) and custom resource patches (`**/resources/**`)
- Platform automerge enabled for Renovate PRs that pass flux-local tests

**Common GitOps Operations:**
- **Manual cluster update**: Push changes to Git, Flux auto-reconciles (or force with `just kube ks-reconcile-all` or `just kube sync-all-ks`)
- **Emergency rollback**: Revert Git commit, Flux reverts cluster state (force with `just kube ks-reconcile-all`)
- **Bypass Flux drift correction**: `kubectl edit` or `helm upgrade` changes don't persist (Flux resets them)
- **Fast-track dependency update**: Approve Renovate PR → tests pass → auto-merge → Flux deploys immediately
- **Sync specific resource**: Use `just kube sync-hr <ns> <name>` for HelmReleases or `just kube sync-ks <ns> <name>` for Kustomizations

## Observability Stack

The observability namespace (`/kubernetes/apps/observability`) provides monitoring, logging, alerting, and status dashboards:

**Core Components:**
- **VictoriaMetrics**: Time series database (drop-in Prometheus replacement) stores metrics
- **VictoriaLogs**: Log aggregation database for storing logs from fluent-bit
- **Grafana**: Visualization and dashboarding for metrics and logs
- **AlertManager**: Handles alert routing, grouping, and notifications (managed by Prometheus Operator)
- **Karma**: AlertManager UI with multi-tenancy support and silencing
- **Gatus**: High-level status dashboard monitoring endpoint availability
- **Fluent-bit**: Log processor collecting logs from pods and forwarding to VictoriaLogs
- **Silence-Operator**: Manages AlertManager silences via CRDs
- **KEDA**: Auto-scales containers on events (e.g., scales down apps when NFS is down)
- **Unpoller**: Collects UniFi Controller metrics for Prometheus

**Key Patterns:**
- Apps protected by Authentik (victoria-metrics, etc.) include `components: [../../../../components/ext-auth]` for UI access control
- Alerts defined via PrometheusRule CRDs (ignored by Renovate in `**/resources/**`)
- Grafana dashboards embedded via ConfigMaps (customizable via `custom.css`)
- External exporters in `kubernetes/apps/observability/exporters/` for custom metrics

## Kubernetes Debugging Essentials

**Native kubectl commands:**
- `kubectl logs -n <ns> deployment/<dep> -f` - Stream logs from deployment
- `kubectl describe helmrelease <hr> -n <ns>` - Check HelmRelease status and events

**Just commands for debugging:**
See [Task Runner Usage](#task-runner-usage) section for full reference. Key debugging commands include:
- Resource inspection: `browse-pvc`, `node-shell`, `view-secret`
- Cleanup: `prune-pods`
- Network: `restart-network`

## Project-Specific Conventions

1. **Naming:** Anchors (`&app`) used in YAML for consistency (e.g., `name: &app authentik` referenced as `*app`)
2. **Substitutions:** Flux postBuild substitutions inject dynamic values (e.g., `CNPG_NAME: pgsql-cluster`)
3. **ConfigMaps from files:** Apps use `configMapGenerator` to embed custom configs (e.g., custom.css)
4. **Renovate integration:** Image tags marked with `# renovate: datasource=docker` for auto-updates
5. **Language servers:** YAML files include JSON schema references for IDE validation

## When Modifying Apps

1. **New app:** Copy existing app directory, update namespace/name in YAML anchors
2. **Chart updates:** Modify `ocirepository.yaml` version tag or rely on Renovate
3. **Secrets:** Add to aKeyless, reference in `externalsecret.yaml` (auto-synced to Secret)
4. **Environment-specific values:** Use `postBuild.substituteFrom` in `ks.yaml` to inject cluster secrets
5. **Dependencies:** Always declare `dependsOn` in `ks.yaml` to ensure resource order
6. **Test locally:** Use `just kube apply-ks <namespace> <app>` to validate before pushing (uses flux-local)
7. **Force reconcile:** Use `just kube ks-reconcile <namespace> <app>` to trigger immediate sync from Git

## File Encryption & SOPS

- Age key stored in `age.key` (must match `$SOPS_AGE_KEY_FILE` env var)
- `.sops.yaml` config file defines encryption rules per path
- Encrypted files marked with `ENC[AES256_GCM` prefix, but deprecated in favor of ExternalSecrets

## Troubleshooting Common Failure Modes

### Stuck HelmReleases (Failed/Progressing Status)

**Diagnosis:**
```bash
# Check HelmRelease status and error message
kubectl describe helmrelease <name> -n <namespace>

# View Helm release history
helm history <name> -n <namespace>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

**Recovery steps:**
```bash
# 1. Delete the HelmRelease to clear stuck state
kubectl delete helmrelease <name> -n <namespace>

# 2. Clean lingering resources (deployments, services, PVCs if not needed)
kubectl delete deployment <name> -n <namespace>
kubectl delete service <name> -n <namespace>

# 3. Force Flux to reconcile and redeploy from Git
just kube ks-reconcile <namespace> <app-name>

# 4. Monitor rollout progress
kubectl rollout status deployment/<name> -n <namespace> -w
```

### ExternalSecret Sync Failures (aKeyless auth issues)

**Diagnosis:**
```bash
# Check ExternalSecret status and conditions
kubectl describe externalsecret <name> -n <namespace>

# Check SecretStore readiness
kubectl describe secretstore <name> -n <namespace>

# View ExternalSecrets operator logs
kubectl logs -n external-secrets deployment/external-secrets -f

# Verify aKeyless credentials are accessible
kubectl get secret -n external-secrets external-secrets-secret -o yaml | grep token
```

**Recovery steps:**
```bash
# 1. Verify cluster-secrets ConfigMap contains aKeyless auth token
kubectl get secret cluster-secrets -n default -o yaml

# 2. Force ExternalSecret resync (add timestamp annotation)
just kube sync-es <namespace> <secret-name>
# Or sync all:
just kube sync-all-es

# 3. Check if SecretStore is Ready
kubectl get secretstore -A

# 4. If ClusterSecretStore fails, restart external-secrets controller
kubectl rollout restart deployment/external-secrets -n external-secrets
```

### CNPG Cluster Failures (Database unavailable)

**Diagnosis:**
```bash
# Check Cluster status
kubectl describe cluster pgsql-cluster -n database

# View CNPG pod logs
kubectl logs -n database pgsql-cluster-1 -f

# Check persistent volumes
kubectl get pv,pvc -n database

# Verify backup status
kubectl get backup -n database
```

**Recovery steps:**
```bash
# 1. Check cluster readiness condition
kubectl get cluster pgsql-cluster -n database -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# 2. If cluster is degraded, check pod status
kubectl get pods -n database -l cnpg.io/cluster=pgsql-cluster

# 3. Retrieve superuser credentials for manual recovery
kubectl get secret -n database pgsql-cluster-superuser -o jsonpath='{.data.password}' | base64 -d

# 4. Connect directly to test database
psql -h pgsql-cluster-rw.database.svc.cluster.local -U postgres -d postgres -W

# 5. If PVC is full, scale down app and clean data, then restart cluster
kubectl scale deployment <app> --replicas=0 -n <app-namespace>
kubectl rollout restart statefulset/cnpg-pgsql-cluster -n database
```

### PVC Mounting & Storage Issues

**Diagnosis:**
```bash
# Check PVC status and events
kubectl describe pvc <claim> -n <namespace>

# Check PV binding
kubectl get pvc,pv -n <namespace>

# Check storage class
kubectl describe storageclass <class-name>

# Verify node has available storage
kubectl top nodes
```

**Recovery steps:**
```bash
# 1. Browse PVC contents to diagnose space/permission issues
just kube browse-pvc <namespace> <claim>

# 2. Check mounted filesystem usage inside pod
kubectl exec -it -n <namespace> deployment/<app> -- df -h /mnt/data

# 3. If PVC is stuck in Pending, check node selectors
kubectl describe pvc <claim> -n <namespace> | grep -A 5 "Events"

# 4. Restart storage controller if all else fails
kubectl rollout restart daemonset/openebs-node-disk-manager -n openebs-system
```

### Pod Evictions & Resource Constraints

**Diagnosis:**
```bash
# Check node resource pressure
kubectl describe nodes | grep -A 5 "Conditions"

# View pod resource requests/limits
kubectl describe pod <pod> -n <namespace> | grep -A 5 "Limits"

# Check actual usage
kubectl top pods -n <namespace>

# View eviction events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep Evicted
```

**Recovery steps:**
```bash
# 1. Scale down non-critical apps to free resources
kubectl scale deployment <low-priority-app> --replicas=0 -n <namespace>

# 2. Restart pod to clear stuck state
kubectl rollout restart deployment/<app> -n <namespace>

# 3. Adjust resource requests/limits in HelmRelease values
# Edit kubernetes/apps/<ns>/<app>/app/helmrelease.yaml
# Update: resources.requests/limits

# 4. Force reconcile to apply new resource specs
just kube ks-reconcile <namespace> <app>
```

### Dependency Resolution Failures

**Diagnosis:**
```bash
# Check Kustomization dependency chain
kubectl describe kustomization <app> -n flux-system

# View dependency errors
kubectl get kustomization -A --sort-by='.status.lastAppliedRevision'

# Check health checks for missing CRDs
kubectl describe crd | grep <resource-kind>
```

**Recovery steps:**
```bash
# 1. Verify all dependsOn resources are Ready
kubectl get kustomization -A | grep False

# 2. Check bootstrap order (Flux deploys in dependency order)
# See: /bootstrap/helmfile.d/01-apps.yaml for correct order

# 3. If health check references missing CRD, ensure Operator deployed first
# Example: apps depending on postgresql.cnpg.io/v1 Cluster
# must have: dependsOn: [{name: cnpg-cluster, namespace: database}]

# 4. Force retry dependency check
just kube ks-reconcile flux-system <dependent-app>
# Or reconcile all:
just kube ks-reconcile-all
```
