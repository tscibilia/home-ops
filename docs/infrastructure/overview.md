# Infrastructure Overview

This cluster uses Talos OS for immutable, declarative node management. Node configs are rendered from Jinja2 templates and applied via `just` workflows.

## Why Talos

- Immutable: no package managers or shell access on nodes
- Minimal: only required services for Kubernetes
- Declarative: node settings live in YAML and are versioned in Git

Manage nodes the same way as Kubernetes resources—update config and apply.

## Cluster Nodes

Three control-plane nodes (scheduling enabled). Configs live in [`talos/nodes/`](https://github.com/tscibilia/home-ops/tree/main/talos/nodes):

| Node | Management IP | Ceph IP | Role | Hardware |
|------|---------------|---------|------|----------|
| k8s-1 | 192.168.5.211 | 192.168.43.11 | Control Plane | Lenovo M70q + Intel iGPU
| k8s-2 | 192.168.5.212 | 192.168.43.12 | Control Plane | Lenovo M70q + Intel iGPU
| k8s-3 | 192.168.5.213 | 192.168.43.13 | Control Plane | Lenovo M70q + Intel iGPU

**Control plane VIP**: `192.168.5.210:6443`

??? info "Why a VIP (Virtual IP)?"
    The VIP (192.168.5.210) floats between the control plane nodes via Cilium L2 announcements. If one node goes down, the VIP moves to another healthy node automatically. This provides high availability—your `kubeconfig` points to the VIP, not individual nodes, so you're always connected to a healthy control plane.

    Configured in base machine config at [`talos/machineconfig.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2):
    ```yaml
    network:
      interfaces:
        - interface: bond0
          vip:
            ip: 192.168.5.210
    ```

??? tip "Dual-Network Architecture"
    Each node has two networks:

    - **Management (192.168.5.x)**: Primary network (bond0) for Kubernetes control plane, pod traffic, and external access
    - **Ceph (192.168.43.x)**: Dedicated network (ceph0) for Rook-Ceph storage traffic

    This separation prevents storage replication from saturating the main network.

??? note "Intel iGPU Acceleration"
    All nodes have Intel integrated graphics (i915) for hardware transcoding. Talos extensions loaded:
    - `extensions.talos.dev/i915`: Intel GPU driver
    - `extensions.talos.dev/intel-ucode`: Intel microcode updates
    - `extensions.talos.dev/mei`: Intel Management Engine Interface

    This enables GPU-accelerated transcoding for media apps like Plex using Dynamic Resource Allocation (DRA).

## Talos Configuration

Node configuration is generated from Jinja2 templates. The structure in [`talos/`](https://github.com/tscibilia/home-ops/tree/main/talos):

```
talos/
├── machineconfig.yaml.j2
├── nodes/
│   ├── k8s-1.yaml.j2          # Node-specific patches (hostname, IPs)
│   ├── k8s-2.yaml.j2
│   └── k8s-3.yaml.j2
├── schematic.yaml.j2          # Talos image customization (extensions)
└── mod.just                   # Just commands for Talos operations
```

Base settings (pod/service networks, control plane endpoint, images, VIP) live in `machineconfig.yaml.j2`. Node files patch hostname and network interfaces (ceph0 IP).

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
just talos render-config k8s-1

# 2. Apply the configuration (requires confirmation)
just talos apply-node k8s-1

# 3. Reboot if needed (some changes require reboot)
just talos reboot-node k8s-1
```

The node applies changes gracefully. Kubernetes reschedules pods during the reboot, so there's no downtime if you have multiple replicas.

### Node Upgrades

#### Upgrade Kubernetes Version

```bash
just talos upgrade-k8s 1.35.0     # Kubernetes upgrade
just talos upgrade-node k8s-1 # Talos OS upgrade per-node
```

Follow a rolling pattern: upgrade one node, wait for Ready, then continue.

## Disaster Recovery

### etcd Snapshots

Talos automatically snapshots etcd. To manually trigger a backup:

```bash
talosctl -n 192.168.5.211 etcd snapshot /tmp/etcd-backup.db
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
