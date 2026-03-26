# Task Runner

`just` with three modules:

```bash
just <module> <command> [args]
```

## Kube

| Command              | Args                  | What it does                                 |
| -------------------- | --------------------- | -------------------------------------------- |
| `sync-ks`            | `<ns> <name>`         | Sync a single Flux Kustomization             |
| `sync-hr`            | `<ns> <name>`         | Sync a single Flux HelmRelease               |
| `sync-es`            | `<ns> <name>`         | Sync a single ExternalSecret                 |
| `sync-all-ks`        | —                     | Sync all Flux Kustomizations                 |
| `sync-all-hr`        | —                     | Sync all Flux HelmReleases                   |
| `sync-all-es`        | —                     | Sync all ExternalSecrets                     |
| `sync-git`           | —                     | Sync GitRepositories                         |
| `sync-oci`           | —                     | Sync OCIRepositories                         |
| `ks-reconcile`       | `<ns> <name>`         | Force Kustomization to reconcile from source |
| `hr-reconcile`       | `<ns> <name>`         | Force HelmRelease to reconcile from source   |
| `ks-reconcile-all`   | —                     | Force all Kustomizations to reconcile        |
| `hr-reconcile-all`   | —                     | Force all HelmReleases to reconcile          |
| `ks-restart`         | —                     | Restart all failed Kustomizations (suspend/resume) |
| `hr-restart`         | —                     | Restart all failed HelmReleases (suspend/resume) |
| `apply-ks`           | `<ns> <ks>`           | Validate locally with flux-local before push |
| `delete-ks`          | `<ns> <ks>`           | Delete a local Flux Kustomization            |
| `view-secret`        | `<ns> <secret>`       | Decode and display a secret                  |
| `browse-pvc`         | `<ns> <claim>`        | Mount PVC to a debug pod                     |
| `node-shell`         | `<node>`              | Interactive shell on a node                  |
| `prune-pods`         | —                     | Clean up Failed, Pending, Succeeded pods     |
| `snapshot`           | `<ns> <name>`         | VolSync snapshot a single PVC                |
| `snapshot-all`       | —                     | VolSync snapshot all PVCs                    |
| `volsync`            | `<action>`            | Suspend or resume VolSync                    |
| `volsync-unlock`     | —                     | Unlock all VolSync restic source repos       |
| `volsync-list`       | `<ns> <name>`         | List available VolSync snapshots             |
| `volsync-restore`    | `<ns> <name> <prev>`  | Restore VolSync backup for an app            |
| `keda`               | `<action>`            | Suspend or resume a Keda ScaledObject        |
| `keda-all`           | `<action>`            | Suspend or resume all Keda ScaledObjects     |
| `restart-network`    | —                     | Restart network stack in dependency order    |

## Talos

| Command              | Args                  | What it does                                 |
| -------------------- | --------------------- | -------------------------------------------- |
| `apply-node`         | `<node>`              | Apply Talos config to a node                 |
| `upgrade-node`       | `<node>`              | Upgrade Talos version on a node              |
| `upgrade-k8s`        | `<version>`           | Upgrade Kubernetes version on the cluster    |
| `reboot-node`        | `<node>`              | Reboot a node                                |
| `shutdown-node`      | `<node>`              | Shutdown a node                              |
| `reset-node`         | `<node>`              | Reset a node (destructive)                   |
| `render-config`      | `<node>`              | Render Talos config for a node               |
| `download-image`     | —                     | Download Talos machine image                 |
| `gen-schematic-id`   | —                     | Generate schematic ID from Talos schematic   |

## Bootstrap

| Command              | Args                  | What it does                                 |
| -------------------- | --------------------- | -------------------------------------------- |
| `talos`              | —                     | Install Talos on nodes                       |
| `kube`               | —                     | Bootstrap Kubernetes                         |
| `kubeconfig`         | —                     | Fetch kubeconfig                             |
| `wait`               | —                     | Wait for nodes to be not-ready               |
| `namespaces`         | —                     | Apply Kubernetes namespaces                  |
| `rook-ceph-external` | —                     | Import external Rook-Ceph cluster resources  |
| `resources`          | —                     | Apply Kubernetes resources                   |
| `crds`               | —                     | Apply Helmfile CRDs                          |
| `apps`               | —                     | Apply Helmfile apps (Cilium → CoreDNS → cert-manager → external-secrets) |
| `cnpg`               | —                     | Create CNPG clusters with recovery from B2 backups |
