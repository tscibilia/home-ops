# Infrastructure Overview

This cluster runs on Talos OS, an immutable Linux distribution designed specifically for Kubernetes. Think of it as a Kubernetes appliance—you can't SSH in and edit files, everything is managed through configuration.

## Why Talos?

Traditional Kubernetes setups require managing the underlying OS: patching, securing SSH, configuring services, etc. Talos eliminates this:

- **Immutable**: No package managers, no shell access. You can't accidentally break it by editing the wrong config file.
- **Minimal**: Runs only what's needed for Kubernetes. Smaller attack surface, fewer things to maintain.
- **Declarative**: Entire node configuration is a YAML file. Want to change something? Update the YAML and apply it.

This means you manage nodes the same way you manage Kubernetes resources: through declarative configuration in Git.

## Cluster Nodes

The cluster consists of three control plane nodes with scheduling enabled. Configuration is defined in [`talos/nodes/`](https://github.com/tscibilia/home-ops/tree/main/talos/nodes):

| Node | Management IP | CEPH IP | Role | Hardware Notes |
|------|---------------|---------|------|----------------|
| talos-m01 | 192.168.5.201 | 10.10.10.8 | Control Plane | NVIDIA Quadro P400 GPU |
| talos-m02 | 192.168.5.202 | 10.10.10.9 | Control Plane | Standard node |
| talos-m03 | 192.168.5.203 | 10.10.10.10 | Control Plane | Standard node |

**Cluster VIP (control plane endpoint)**: `192.168.5.200:6443`

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

    This separation prevents storage replication from saturating the main network. Both networks use 9000 MTU (jumbo frames) for better performance with 2.5GbE networking.

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
├── machineconfig.yaml.j2      # Base machine config (shared across all nodes)
├── nodes/
│   ├── talos-m01.yaml.j2     # Node-specific overrides (IP, hardware)
│   ├── talos-m02.yaml.j2
│   └── talos-m03.yaml.j2
├── schematic.yaml.j2          # Talos image customization
└── mod.just                   # Just commands for Talos operations
```

### How Configuration Works

The base configuration in [`machineconfig.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2) defines cluster-wide settings:

- **Cluster name**: `main` (line 130)
- **Control plane endpoint**: `https://192.168.5.200:6443` (line 132)
- **Pod network**: `10.42.0.0/16` (line 145)
- **Service network**: `10.43.0.0/16` (line 147)
- **Kubernetes version**: Check [`talos/machineconfig.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2) for current version
- **Talos version**: Check [`talos/machineconfig.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2) for current image

Node-specific configs in `talos/nodes/*.yaml.j2` override:

- Hostname
- IP addresses (management + CEPH)
- Hardware-specific settings (GPU, MAC addresses)

??? example "Real Config Example"
    From [`talos/nodes/talos-m01.yaml.j2:1-17`](https://github.com/tscibilia/home-ops/blob/main/talos/nodes/talos-m01.yaml.j2#L1-L17):
    ```yaml
    machine:
      network:
        hostname: talos-m01
        interfaces:
          - deviceSelector:
              hardwareAddr: bc:24:11:a9:a3:43
            addresses:
              - 192.168.5.201/24
            routes:
              - network: 0.0.0.0/0
                gateway: 192.168.5.1
            mtu: 9000
            dhcp: true
            vip:
              ip: 192.168.5.200
    ```

### Secrets Management

Notice the `ak://` references in [`machineconfig.yaml.j2`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2):

```yaml
machine:
  ca:
    crt: ak://talos/MACHINE_CA_CRT
    key: ak://talos/MACHINE_CA_KEY
  token: ak://talos/MACHINE_TOKEN
```

These are fetched from aKeyless during rendering. Certificates and keys never live in Git—they're injected at build time using `akeyless-inject`.

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

### Step-by-Step Bootstrap

=== "1. Install Talos"
    ```bash
    just bootstrap talos
    ```

    Installs Talos on all nodes. Each node boots from a Talos ISO and receives its rendered machine configuration.

=== "2. Bootstrap Kubernetes"
    ```bash
    just bootstrap k8s
    ```

    Initializes the Kubernetes cluster. The first control plane node (determined by `talosctl config info`) bootstraps etcd and the Kubernetes control plane.

=== "3. Fetch Kubeconfig"
    ```bash
    just bootstrap kubeconfig
    ```

    Retrieves the `kubeconfig` file from the cluster and saves it to the repo root. This lets `kubectl` authenticate to the cluster.

=== "4. Wait for Nodes"
    ```bash
    just bootstrap wait
    ```

    Polls all nodes until they report Ready status. Ensures Kubernetes is stable before deploying apps.

=== "5. Apply Namespaces"
    ```bash
    just bootstrap namespaces
    ```

    Creates all Kubernetes namespaces by applying `kubernetes/apps/*/namespace.yaml` files. Apps can't deploy without their namespaces existing first.

=== "6. Apply Resources"
    ```bash
    just bootstrap resources
    ```

    Applies Kubernetes resources from templates in `kubernetes/flux/`. Uses `minijinja` for templating and `akeyless-inject` for secret substitution.

=== "7. Apply CRDs"
    ```bash
    just bootstrap crds
    ```

    Installs Custom Resource Definitions via Helmfile. CRDs define new resource types (like `HelmRelease`, `Kustomization`) that apps depend on.

=== "8. Deploy Apps"
    ```bash
    just bootstrap apps
    ```

    Deploys core infrastructure apps via Helmfile in strict dependency order:

    1. **Cilium**: CNI networking (eBPF-based, replaces kube-proxy)
    2. **CoreDNS**: Cluster DNS resolution
    3. **Spegel**: OCI image mirror (reduces external registry load)
    4. **cert-manager**: TLS certificate automation
    5. **external-secrets**: Syncs secrets from aKeyless

    Defined in [`bootstrap/helmfile.d/01-apps.yaml`](https://github.com/tscibilia/home-ops/blob/main/bootstrap/helmfile.d/01-apps.yaml).

=== "Full Bootstrap"
    ```bash
    just bootstrap default
    ```

    Runs all of the above steps in sequence. Use this to build the cluster from scratch.

??? warning "Bootstrap is Destructive"
    `just bootstrap talos` wipes nodes and reinstalls Talos. Make sure you have backups before running this!

    For configuration updates on existing nodes, use `just talos apply-node <node>` instead.

## Helmfile: Bootstrap Dependency Manager

The [`bootstrap/`](https://github.com/tscibilia/home-ops/tree/main/bootstrap) directory uses Helmfile to deploy core infrastructure. Think of it like Docker Compose for Helm—it defines multiple releases with dependencies.

```yaml title="bootstrap/helmfile.d/01-apps.yaml (simplified)"
releases:
  - name: cilium
    namespace: kube-system
    chart: cilium/cilium

  - name: coredns
    namespace: kube-system
    needs:  # Waits for cilium to be ready
      - kube-system/cilium
    chart: coredns/coredns
```

The `needs` key ensures proper ordering—coredns won't deploy until cilium is healthy.

??? info "Why Helmfile instead of Flux?"
    Flux is great for ongoing operations, but bootstrapping requires:

    - Running **before** the cluster has CRDs installed
    - **External dependencies** (like cert-manager before any Certificates exist)
    - **Strict ordering** without circular dependencies

    Helmfile runs from your local machine with `kubectl` and `helm`, so it can handle bootstrap dependencies that Flux can't orchestrate yet.

    After bootstrap completes, Flux takes over and Helmfile is rarely used again.

## Node Management

### Applying Configuration Changes

When you edit Talos configuration:

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
just talos upgrade-k8s 1.35.0
```

Upgrades Kubernetes across all control plane nodes. Talos orchestrates the rolling upgrade—one node at a time, waiting for each to be Ready before proceeding.

#### Upgrade Talos OS

```bash
# Upgrade a single node
just talos upgrade-node talos-m01
```

Talos downloads the new OS image (currently using v1.11.5 per [`machineconfig.yaml.j2:54`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2#L54)), applies it atomically, and reboots. If the upgrade fails, the node rolls back to the previous version automatically.

??? tip "Rolling Upgrades"
    Always upgrade one node at a time:

    ```bash
    just talos upgrade-node talos-m01
    kubectl wait --for=condition=ready node/talos-m01 --timeout=10m

    just talos upgrade-node talos-m02
    kubectl wait --for=condition=ready node/talos-m02 --timeout=10m

    just talos upgrade-node talos-m03
    kubectl wait --for=condition=ready node/talos-m03 --timeout=10m
    ```

    With 3 control planes, you maintain quorum throughout the upgrade. Workloads get rescheduled to healthy nodes automatically.

## Disaster Recovery

### etcd Snapshots

Talos automatically snapshots etcd. To manually trigger a backup:

```bash
talosctl -n 192.168.5.201 etcd snapshot /tmp/etcd-backup.db
```

Store this safely—it contains your entire cluster state (except application data).

### Rebuilding a Failed Node

If a node completely dies:

1. Boot from Talos ISO
2. Apply its configuration: `just talos apply-node <node>`
3. The node rejoins the cluster automatically
4. Kubernetes reschedules pods that were on the failed node

### Rebuilding the Entire Cluster

If everything is lost:

1. Restore this Git repository
2. Run `just bootstrap default`
3. Restore application data from VolSync backups (see [Storage Guide](../kubernetes/storage.md#volsync-backups))

??? danger "Destructive Commands"
    These commands require confirmation prompts:

    - `just talos reset-node <node>`: Factory reset (wipes all data)
    - `just bootstrap talos`: Reinstalls Talos on all nodes (wipes cluster)
    - `just talos shutdown-node <node>`: Powers off the node

    Always verify you have backups before running these!

## System Tunables

The cluster has several optimizations in [`machineconfig.yaml.j2:97-117`](https://github.com/tscibilia/home-ops/blob/main/talos/machineconfig.yaml.j2#L97-L117):

- **TCP BBR congestion control**: Better performance on 2.5GbE network
- **Increased inotify limits**: For apps that watch many files
- **Jumbo frames (MTU 9000)**: Reduces packet overhead on local network
- **TCP window scaling**: Better throughput for long-lived connections
- **NFS optimizations**: 16 connections (`nconnect=16`), hard mounts
- **Hugepages (2GB)**: Reserved for workloads that can use them

These tunables are based on the hardware (2.5GbE networking, CEPH storage) and workload patterns (media streaming, database replication).

## Next Steps

- [**Bootstrap Reference**](bootstrap.md): Detailed bootstrap process documentation
- [**Talos Commands**](../operations/task-runner.md#talos-module): Full command reference
- [**Kubernetes Layer**](../kubernetes/overview.md): How apps are deployed on top of this infrastructure

??? info "Want to dig deeper?"
    - Check out the [DeepWiki Talos section](https://deepwiki.com/tscibilia/home-ops?tab=talos) for AI-generated insights
    - Read the [official Talos documentation](https://www.talos.dev/latest/introduction/)
