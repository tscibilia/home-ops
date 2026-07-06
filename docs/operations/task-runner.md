# Task Runner

`just` with three modules:

```bash
just <module> <command> [args]
```

## Kube

| Command           | Args                      | What it does                                       |
| ----------------- | ------------------------- | -------------------------------------------------- |
| `sync`            | `<resource> [<ns> <app>]` | Sync hr/ks/es/gitrepo/ocirepo — targeted or all    |
| `reconcile-ks`    | `[<ns> <app>]`            | Force Kustomization(s) to reconcile from source    |
| `reconcile-hr`    | `[<ns> <app>]`            | Force HelmRelease(s) to reconcile from source      |
| `restart-ks`      | —                         | Restart all failed Kustomizations (suspend/resume) |
| `restart-hr`      | —                         | Restart all failed HelmReleases (suspend/resume)   |
| `apply-ks`        | `<ns> <ks>`               | Server-side apply, not for testing purposes        |
| `delete-ks`       | `<ns> <ks>`               | Delete a local Flux Kustomization                  |
| `browse-pvc`      | `<ns> <claim>`            | Mount PVC to a debug pod                           |
| `node-shell`      | `<node>`                  | Interactive shell on a node                        |
| `prune-pods`      | —                         | Clean up Failed, Pending, Succeeded pods           |
| `volsync`         | `<suspend\|resume>`       | Suspend or resume Kopiur                           |
| `snapshot`        | `[<ns> <app>]`            | Snapshot Kopiur PVC(s) — targeted or all           |
| `restore`         | `<ns> <app> [<prev>]`     | Restore Kopiur backup for an app                   |
| `restart-network` | —                         | Restart network stack in dependency order          |

## Talos

| Command            | Args        | What it does                               |
| ------------------ | ----------- | ------------------------------------------ |
| `apply-node`       | `<node>`    | Apply Talos config to a node               |
| `upgrade-node`     | `<node>`    | Upgrade Talos version on a node            |
| `upgrade-k8s`      | `<version>` | Upgrade Kubernetes version on the cluster  |
| `reboot-node`      | `<node>`    | Reboot a node                              |
| `shutdown-node`    | `<node>`    | Shutdown a node                            |
| `reset-node`       | `<node>`    | Reset a node (destructive)                 |
| `render-config`    | `<node>`    | Render Talos config for a node             |
| `download-image`   | —           | Download Talos machine image               |
| `gen-schematic-id` | —           | Generate schematic ID from Talos schematic |

## Bootstrap

| Command              | Args | What it does                                                             |
| -------------------- | ---- | ------------------------------------------------------------------------ |
| `talos`              | —    | Install Talos on nodes                                                   |
| `kube`               | —    | Bootstrap Kubernetes                                                     |
| `kubeconfig`         | —    | Fetch kubeconfig                                                         |
| `wait`               | —    | Wait for nodes to be not-ready                                           |
| `namespaces`         | —    | Apply Kubernetes namespaces                                              |
| `rook-ceph-external` | —    | Import external Rook-Ceph cluster resources                              |
| `resources`          | —    | Apply Kubernetes resources                                               |
| `crds`               | —    | Apply Helmfile CRDs                                                      |
| `apps`               | —    | Apply Helmfile apps (Cilium → CoreDNS → cert-manager → external-secrets) |
| `cnpg`               | —    | Create CNPG clusters with recovery from B2 backups                       |
