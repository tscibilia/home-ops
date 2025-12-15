# Task Runner Reference

All cluster operations use `just` as the task runner. Commands are organized into three modules: `bootstrap`, `kube` (Kubernetes), and `talos`.

## Command Structure

```bash
just <module> <command> [args]
```

Examples:
```bash
just bootstrap           # Run full bootstrap
just kube sync-all-hr    # Sync all Helm releases
just talos reboot-node talos-m01  # Reboot a node
```

View all commands:
```bash
just --list        # All commands
just kube          # Kubernetes module commands
just talos         # Talos module commands
just bootstrap     # Bootstrap module commands (shows help)
```

---

## Bootstrap Module

Commands for initial cluster setup. Defined in [`bootstrap/mod.just`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/mod.just).

### Full Bootstrap

| Command | Description |
|---------|-------------|
| `just bootstrap` | **Run full bootstrap sequence**: talos → k8s → kubeconfig → wait → namespaces → resources → crds → apps → cnpg |

This is the main command for rebuilding the cluster from scratch. It runs all bootstrap stages in order.

### Individual Stages

Run specific bootstrap stages:

| Command | Description | What It Does |
|---------|-------------|--------------|
| `just bootstrap talos` | Install Talos OS on all nodes | Applies Talos machine configs from `talos/nodes/*.yaml.j2` to all configured nodes using minijinja templates |
| `just bootstrap k8s` | Bootstrap Kubernetes | Initializes the Kubernetes control plane on the first controller node |
| `just bootstrap kubeconfig [lb]` | Fetch kubeconfig | Downloads `kubeconfig` from cluster; optional `lb` parameter sets load balancer type (default: `cilium`) |
| `just bootstrap wait` | Wait for nodes to be ready | Polls nodes until all report Ready status |
| `just bootstrap namespaces` | Apply Kubernetes namespaces | Creates all namespaces from `kubernetes/apps/*/namespace.yaml` |
| `just bootstrap rook-ceph-external` | Import external Rook-Ceph resources | Imports external Ceph cluster configuration (if using external Ceph) |
| `just bootstrap resources` | Apply Kubernetes resources from templates | Renders and applies `bootstrap/resources.yaml.j2` with `akeyless-inject.sh` |
| `just bootstrap crds` | Apply CRDs from Helmfile | Installs Custom Resource Definitions from `bootstrap/helmfile.d/00-crds.yaml` |
| `just bootstrap apps` | Deploy core apps via Helmfile | Deploys core infrastructure (Cilium, CoreDNS, Spegel, cert-manager, external-secrets) from `bootstrap/helmfile.d/01-apps.yaml` |
| `just bootstrap cnpg` | Create CNPG clusters with recovery | Attempts to restore CNPG clusters from backup if backups exist; otherwise Flux creates fresh clusters |

??? info "Bootstrap Dependencies"
    The bootstrap process has strict ordering requirements:

    1. **Talos** must be installed before Kubernetes
    2. **Kubernetes** must be initialized before fetching kubeconfig
    3. **Namespaces** must exist before resources
    4. **CRDs** must exist before apps that use them
    5. **Apps** deploy in dependency order via Helmfile: Cilium → CoreDNS → Spegel → cert-manager → external-secrets

---

## Kubernetes Module

Commands for managing Kubernetes resources and Flux. Defined in [`kubernetes/mod.just`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/mod.just).

### Resource Management

| Command | Description |
|---------|-------------|
| `just kube browse-pvc <namespace> <claim>` | Mount PVC to debug pod and open interactive shell |
| `just kube node-shell <node>` | Open interactive shell on a specific node |
| `just kube prune-pods` | Delete all pods in Failed, Pending, or Succeeded state |
| `just kube view-secret <namespace> <secret>` | Decode and view secret contents in plain text |

### Flux Operations

**Sync Commands** (force immediate reconciliation):

| Command | Description |
|---------|-------------|
| `just kube sync-git` | Sync all GitRepositories |
| `just kube sync-oci` | Sync all OCIRepositories |
| `just kube sync-es <namespace> <name>` | Force sync a single ExternalSecret |
| `just kube sync-hr <namespace> <name>` | Force sync a single HelmRelease |
| `just kube sync-ks <namespace> <name>` | Force sync a single Kustomization |
| `just kube sync-all-es` | Sync all ExternalSecrets across cluster |
| `just kube sync-all-hr` | Sync all HelmReleases across cluster |
| `just kube sync-all-ks` | Sync all Kustomizations across cluster |

**Reconcile Commands** (reconcile from source, rebuilds from Git):

| Command | Description |
|---------|-------------|
| `just kube ks-reconcile <namespace> <name>` | Force Kustomization to reconcile from Git source |
| `just kube hr-reconcile <namespace> <name>` | Force HelmRelease to reconcile from Git source |
| `just kube ks-reconcile-all` | Force all Kustomizations to reconcile from source |
| `just kube hr-reconcile-all` | Force all HelmReleases to reconcile from source |

**Restart Commands** (suspend/resume failed resources):

| Command | Description |
|---------|-------------|
| `just kube ks-restart` | Suspend and resume all failed Kustomizations |
| `just kube hr-restart` | Suspend and resume all failed HelmReleases |

??? tip "Sync vs Reconcile"
    - **Sync** (`sync-*`): Annotates resources to trigger immediate reconciliation. Use when Git hasn't changed but you want Flux to reapply.
    - **Reconcile** (`*-reconcile`): Forces Flux to fetch from Git source and rebuild. Use after pushing changes to Git.

### Local Development

| Command | Description |
|---------|-------------|
| `just kube apply-ks <namespace> <app>` | Apply local Kustomization using `flux-local` (dry-run style validation) |
| `just kube delete-ks <namespace> <app>` | Delete local Kustomization |

Use `apply-ks` to test Flux manifests locally before pushing to Git. This uses `flux-local` to render and validate without affecting the cluster.

### VolSync Backups

| Command | Description |
|---------|-------------|
| `just kube snapshot <namespace> <name>` | Trigger manual snapshot for single PVC |
| `just kube snapshot-all` | Trigger snapshots for all VolSync-enabled PVCs |
| `just kube volsync <state>` | Suspend or resume VolSync (`state`: `suspend` or `resume`) |
| `just kube volsync-unlock` | Unlock all Restic repositories (if locked due to interrupted backups) |
| `just kube volsync-list <namespace> <name>` | List available snapshots for an app |
| `just kube volsync-restore <namespace> <name> <previous>` | Restore from backup (1=latest, 2=second most recent, etc.) |

??? example "Restore Workflow"
    The restore process automatically:

    1. Pauses KEDA ScaledObject (if exists)
    2. Suspends Flux Kustomization and HelmRelease
    3. Scales down the app
    4. Creates ReplicationDestination with restore snapshot
    5. Waits for restore to complete
    6. Resumes Flux resources
    7. Resumes KEDA (if exists)

    Example:
    ```bash
    # List available snapshots
    just kube volsync-list default immich

    # Restore from 2nd most recent snapshot
    just kube volsync-restore default immich 2
    ```

### KEDA Auto-scaling

| Command | Description |
|---------|-------------|
| `just kube keda <state> <namespace> <name>` | Suspend or resume single ScaledObject (`state`: `suspend` or `resume`) |
| `just kube keda-all <state>` | Suspend or resume all ScaledObjects |

Suspending KEDA pauses auto-scaling, effectively pinning the app at its current replica count.

### Network Stack

| Command | Description |
|---------|-------------|
| `just kube restart-network` | Restart network components in dependency order: CoreDNS → Cilium → Cloudflared → external-dns → unifi-dns → Envoy Gateway |

Use this when networking is broken or after major configuration changes. Components restart sequentially to maintain dependencies.

---

## Talos Module

Commands for managing Talos OS nodes. Defined in [`talos/mod.just`](https://github.com/tscibilia/home-ops/blob/main/talos/mod.just).

### Node Management

| Command | Description |
|---------|-------------|
| `just talos apply-node <node> [args]` | Apply Talos configuration to a specific node (renders config from templates with `akeyless-inject.sh`) |
| `just talos render-config <node>` | Render Talos configuration for a node (preview before applying) |
| `just talos reboot-node <node>` | Reboot node with confirmation prompt (uses `powercycle` reboot mode) |
| `just talos shutdown-node <node>` | Shutdown node with confirmation prompt |
| `just talos reset-node <node>` | Factory reset node with confirmation prompt (**destructive!**) |

??? warning "Destructive Commands"
    These commands require confirmation prompts:

    - `reset-node`: Wipes all data, returns node to factory state
    - `reboot-node` and `shutdown-node`: Gracefully restarts/stops node

    Always ensure you have backups before running destructive commands!

### Upgrades

| Command | Description |
|---------|-------------|
| `just talos upgrade-k8s <version>` | Upgrade Kubernetes version on all control plane nodes (e.g., `just talos upgrade-k8s 1.35.0`) |
| `just talos upgrade-node <node>` | Upgrade Talos OS on a specific node (uses image from `machineconfig.yaml.j2`) |

??? info "Upgrade via tuppr"
    In normal operation, upgrades are handled automatically by **tuppr** (the system-upgrade controller). Renovate creates PRs to update `TalosUpgrade` and `KubernetesUpgrade` CRDs, and tuppr orchestrates rolling upgrades.

    Use manual upgrade commands only as a fallback if tuppr fails or you need immediate control.

### Image Management

| Command | Description |
|---------|-------------|
| `just talos download-image <version> <schematic>` | Download Talos ISO image from factory.talos.dev |
| `just talos gen-schematic-id <node>` | Generate schematic ID for a node's hardware configuration |

---

## Utility Commands

These are internal commands used by other recipes. Generally not called directly.

### Bootstrap Utilities

Located in root [`.justfile`](https://github.com/tscibilia/home-ops/blob/main/.justfile):

| Command | Description |
|---------|-------------|
| `just log <level> <msg> [args]` | Log a message with timestamp (uses `gum log`) |
| `just template <file> [args]` | Render Jinja2 template and inject aKeyless secrets via `akeyless-inject.sh` |
| `just check-tools <tools...>` | Verify required CLI tools are installed; exits with error if missing |

### Kubernetes Utilities

Internal commands in [`kubernetes/mod.just`](https://github.com/tscibilia/home-ops/blob/main/kubernetes/mod.just):

| Command | Description |
|---------|-------------|
| `just kube render-local-ks <ns> <ks>` | Render Flux Kustomization locally using `flux-local build` |
| `just kube flux-suspend <ns> <name>` | Suspend Flux Kustomization and HelmRelease for an app |
| `just kube flux-resume <ns> <name>` | Resume Flux Kustomization and HelmRelease, force reconcile |
| `just kube app-scale-down <ns> <name>` | Scale down deployment or statefulset to 0 replicas, wait for pods to terminate |

### Talos Utilities

Internal commands in [`talos/mod.just`](https://github.com/tscibilia/home-ops/blob/main/talos/mod.just):

| Command | Description |
|---------|-------------|
| `just talos machine-controller <node>` | Check if node is a control plane node (returns "true" or "") |
| `just talos machine-nvidia <node>` | Check if node has NVIDIA GPU (returns "true" or "") |
| `just talos machine-image` | Extract Talos image from `machineconfig.yaml.j2` |

---

## Common Workflows

### Updating an App

```bash
# 1. Edit Helm values
nano kubernetes/apps/media/plex/app/helmrelease.yaml

# 2. Test locally (optional)
just kube apply-ks media plex

# 3. Commit and push
git add kubernetes/apps/media/plex/
git commit -m "feat(plex): update config"
git push

# 4. Force reconcile (or wait for automatic sync)
just kube ks-reconcile media plex
```

### Rebuilding a Failed App

```bash
# 1. Delete HelmRelease to clear stuck state
kubectl delete helmrelease <app> -n <namespace>

# 2. Force reconcile from Git
just kube ks-reconcile <namespace> <app>

# 3. Watch rollout
kubectl rollout status deployment/<app> -n <namespace> -w
```

### Node Reboot

```bash
# Reboot one node at a time
just talos reboot-node talos-m01
kubectl wait --for=condition=ready node/talos-m01 --timeout=10m

just talos reboot-node talos-m02
kubectl wait --for=condition=ready node/talos-m02 --timeout=10m

just talos reboot-node talos-m03
kubectl wait --for=condition=ready node/talos-m03 --timeout=10m
```

### Restore from Backup

```bash
# 1. List snapshots
just kube volsync-list default immich

# 2. Restore from snapshot (1=latest)
just kube volsync-restore default immich 1

# 3. Verify app is running
kubectl get pods -n default -l app.kubernetes.io/name=immich
```

---

## Tool Dependencies

All commands check for required tools before running. Install via `mise` (`.mise.toml`):

```bash
mise install
```

**Required tools:**
- `kubectl` - Kubernetes CLI
- `flux` - Flux CD CLI
- `talosctl` - Talos OS CLI
- `helm` - Helm package manager
- `helmfile` - Helmfile deployment tool
- `kustomize` - Kustomize CLI
- `flux-local` - Local Flux testing
- `akeyless` - aKeyless CLI
- `jq` - JSON processor
- `yq` - YAML processor
- `gum` - CLI UI tools
- `minijinja-cli` - Jinja2 template renderer

---

## Next Steps

- [Operations Overview](overview.md): Day-to-day workflows
- [Troubleshooting Guide](troubleshooting.md): Common issues and fixes
