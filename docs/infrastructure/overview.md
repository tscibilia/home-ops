# Infrastructure Overview

This cluster uses Talos OS for immutable, declarative node management. Node configs are rendered from Jinja2 templates and applied via `just` workflows.

## Why Talos

- Immutable: no package managers or shell access on nodes
- Minimal: only required services for Kubernetes
- Declarative: node settings live in YAML and are versioned in Git

Manage nodes the same way as Kubernetes resources—update config and apply.

## Cluster Nodes

Three control-plane nodes (scheduling enabled). Configs live in [`talos/nodes/`](https://github.com/tscibilia/home-ops/tree/main/talos/nodes):

| Node | Management IP | CEPH IP | Role | Notes |
|------|---------------|---------|------|-------|
| talos-m01 | 192.168.5.201 | 10.10.10.8 | Control Plane | NVIDIA Quadro P400 (GPU)
| talos-m02 | 192.168.5.202 | 10.10.10.9 | Control Plane | Standard
| talos-m03 | 192.168.5.203 | 10.10.10.10 | Control Plane | Standard

**Control plane VIP**: `192.168.5.200:6443`

??? info "Why a VIP (Virtual IP)?"
    The VIP (192.168.5.200) floats between the control plane nodes. If one node goes down, the VIP moves to another healthy node automatically. This provides high availability—your `kubeconfig` points to the VIP, not individual nodes, so you're always connected to a healthy control plane.

    Configured in each node's YAML at [`talos/nodes/talos-m0X.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/nodes/talos-m01.yaml.j2):
    ```yaml
    vip:
      ip: 192.168.5.200
    ```

??? tip "Dual-Network Architecture"
    Notice each node has two networks:

    - **Management (192.168.5.x)**: Primary network for Kubernetes control plane, pod traffic, and external access
    - **CEPH (10.10.10.x)**: Dedicated network for Rook-Ceph storage traffic

    This separation prevents storage replication from saturating the main network. Only Ceph currently uses 9000 MTU (jumbo frames) for better performance with 2.5GbE networking.

??? note "GPU Acceleration"
    talos-m01 has an NVIDIA Quadro P400 GPU with drivers loaded via kernel modules. See [`talos/nodes/talos-m01.yaml.j2:36-40`](https://github.com/tscibilia/home-ops/blob/main/talos/nodes/talos-m01.yaml.j2#L36-L40):
    ```yaml
    kernel:
      modules:
        - name: nvidia
        - name: nvidia_uvm
        - name: nvidia_drm
        - name: nvidia_modeset
    ```

    This enables GPU-accelerated transcoding for media apps like Plex/Jellyfin.

## Talos Configuration

Node configuration is generated from Jinja2 templates. The structure in [`talos/`](https://github.com/tscibilia/home-ops/tree/main/talos):

```
talos/
├── machineconfig.yaml.j2
├── nodes/
│   ├── talos-m01.yaml.j2     # Node-specific overrides (IP, hardware)
│   ├── talos-m02.yaml.j2
│   └── talos-m03.yaml.j2
├── schematic.yaml.j2          # Talos image customization
└── mod.just                   # Just commands for Talos operations
```

Base settings (pod/service networks, control plane endpoint, images) live in `machineconfig.yaml.j2`. Node files override hostname, IPs, and hardware options.

Secrets (certs, tokens) are referenced as `ak://...` and injected at render time via `akeyless-inject`—they are not stored in Git.

## Bootstrap Process

Setting up the cluster from scratch follows a specific order. Everything is orchestrated through `just bootstrap` commands defined in [`bootstrap/mod.just`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/mod.just):

```mermaid
graph LR
    A[Install Talos] --> B[Bootstrap K8s]
    B --> C[Fetch Kubeconfig]
    C --> D[Apply Namespaces]
    D --> E[Apply Resources]
    E --> F[Apply CRDs]
    F --> G[Deploy Core Apps]
    G --> H[Flux Sync]
```

Important commands (use `just bootstrap default` to run all):

```bash
just bootstrap talos      # install Talos on nodes (destructive)
just bootstrap k8s        # initialize Kubernetes
just bootstrap kubeconfig
just bootstrap namespaces
just bootstrap resources
just bootstrap crds
just bootstrap apps
```

`bootstrap/helmfile.d/01-apps.yaml` defines core app ordering (cilium → coredns → cert-manager → external-secrets).

## Node operations

Render, apply, and reboot:

```bash
# 1. Render the config to see what will change
just talos render-config talos-m01

# 2. Apply the configuration (requires confirmation)
just talos apply-node talos-m01

# 3. Reboot if needed (some changes require reboot)
just talos reboot-node talos-m01
```

The node applies changes gracefully. Kubernetes reschedules pods during the reboot, so there's no downtime if you have multiple replicas.

### Node Upgrades

#### Upgrade Kubernetes Version

```bash
just talos upgrade-k8s 1.35.0     # Kubernetes upgrade
just talos upgrade-node talos-m01 # Talos OS upgrade per-node
```

Follow a rolling pattern: upgrade one node, wait for Ready, then continue.

## Disaster Recovery

### etcd Snapshots

Talos automatically snapshots etcd. To manually trigger a backup:

```bash
talosctl -n 192.168.5.201 etcd snapshot /tmp/etcd-backup.db
```

Store this safely—it contains your entire cluster state (except application data).

### Rebuilding a Failed Node
1. Boot from Talos ISO
2. Apply its configuration: `just talos apply-node <node>`

### Rebuilding the Entire Cluster
1. Restore this Git repository
2. Run `just bootstrap default`

??? danger "Destructive Commands"
    These commands require confirmation prompts:

    - `just talos reset-node <node>`: Factory reset (wipes all data)
    - `just bootstrap talos`: Reinstalls Talos on all nodes (wipes cluster)
    - `just talos shutdown-node <node>`: Powers off the node

    Always verify you have backups before running these!

## Tunables

Machine-level optimizations include BBR, increased inotify limits, MTU 9000, TCP window scaling, NFS tuning, and hugepages—tuned for media and CEPH workloads.

## References

- [Bootstrap Reference](bootstrap.md): Detailed bootstrap process documentation
- [Talos Commands](../operations/task-runner.md#talos-module): Full command reference
- [Kubernetes Reference](../kubernetes/overview.md): How apps are deployed on top of this infrastructure

```
*** End Patch
