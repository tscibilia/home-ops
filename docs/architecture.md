# Architecture

## Hardware

Three Lenovo ThinkCentre M70q Tiny (Gen 3) control-plane nodes + one dedicated GPU worker running Talos Linux.

| Node   | Role          | Mgmt hostname   | Ceph hostname   |
| ------ | ------------- | --------------- | --------------- |
| k8s-1  | control-plane | k8s-1.internal  | ceph-1.internal |
| k8s-2  | control-plane | k8s-2.internal  | ceph-2.internal |
| k8s-3  | control-plane | k8s-3.internal  | ceph-3.internal |
| ai3090 | worker        | ai3090.internal | —               |

- **API endpoint**: `192.168.5.250:6443` (BGP-announced LoadBalancer)
- **GPU (k8s-1/2/3)**: Intel i915 iGPU — Plex and Jellyfin hardware transcoding
- **GPU (ai3090)**: NVIDIA GPU (tainted `nvidia.com/gpu:NoSchedule`) — llama-cpp, comfyui
- **OS configs**: Minijinja templates in `kubernetes/talos/`, never edit rendered output directly

## Networking

### Physical

- **UDM-Pro** (192.168.5.1): router, firewall, DNS controller
- **Primary LAN**: 192.168.5.0/24 — management and cluster traffic
- **Ceph network**: 192.168.43.0/24 — dedicated 2.5GbE for storage replication
- **VPN VLAN**: 192.168.99.0/24 — VLAN 99 via Multus for qBittorrent

### LAN DNS

UniFi controller manages the `.internal` domain for non-cluster hosts:

- truenas.internal, clonenas.internal — static entries in UniFi
- The `unifi-dns` pod syncs cluster HTTPRoutes into UniFi so LAN clients resolve cluster services without touching Cloudflare

### Cluster

!!! warning "No kube-proxy"
    Cilium is the eBPF replacement. Standard kube-proxy debug tools don't apply. Use `cilium` CLI or Hubble for network debugging.

- **CNI**: Cilium — eBPF-based, completely replaces kube-proxy
- **Load balancing**: Cilium BGP control plane — eBGP peers with UDM-Pro (ASN 64513/64514), ECMP across all 3 control-plane nodes. IP pool `192.168.5.0/24`, advertised as `/32` host routes.
- **Routing**: HTTPRoute resources, not legacy Ingress objects
- **Auth**: Authentik SSO via Envoy SecurityPolicy forward-auth

**Ingress** — Envoy Gateway runs two instances:

=== "envoy-external"

    Internet-facing. A Pangolin VPS terminates the Cloudflare-proxied A record and forwards traffic through a Newt WireGuard tunnel to this gateway. All `*.t0m.co` requests enter through this gateway.

=== "envoy-internal"

    LAN-only. UniFi DNS points local clients directly to this gateway's LoadBalancer IP. No Cloudflare involvement.

### DNS

Three layers of resolution:

```mermaid
flowchart LR
    Pod -->|cluster DNS| CoreDNS["CoreDNS\n10.43.0.10"]
    LAN["LAN Client"] -->|*.t0m.co| UniFi["unifi-dns\n→ UniFi Controller"]
    Internet -->|*.t0m.co| CF["external-dns\n→ Cloudflare"]
    UniFi --> EI[envoy-internal]
    CF --> VPS["Pangolin VPS\n+ Newt tunnel"] --> EE[envoy-external]
```

| Layer        | Service      | Scope                                      |
| ------------ | ------------ | ------------------------------------------ |
| In-cluster   | CoreDNS      | Pod-to-pod, service discovery (10.43.0.10) |
| LAN          | unifi-dns    | Syncs HTTPRoutes → UniFi controller        |
| External     | external-dns | Syncs envoy-external routes → Cloudflare (proxied) |

### Certificates

cert-manager handles TLS via Let's Encrypt with DNS-01 challenges through Cloudflare API.

## Storage

| Class             | Backend                  | Use                                        |
| ----------------- | ------------------------ | ------------------------------------------ |
| ceph-ssd (default)| Rook-Ceph, Samsung SSDs  | All persistent workloads                   |
| openebs-hostpath  | Local node storage       | CNPG clusters, victoria-logs, actions-runner |
| nfs-media         | TrueNAS NFS              | Media libraries                            |

!!! info "S3-compatible object storage via RustFS (ceph-ssd backed). No ceph-rbd, no CephFS."

### Backups

- **VolSync**: Restic-based PVC snapshots → NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/volsync`); rclone syncs to Backblaze B2
- **CNPG**: pgdumps (daily) → NFS on `clonenas.internal` (`/mnt/vault/backups/kubernetes/postgres`); Barman-cloud WAL archiving → Backblaze B2

## Databases

### PostgreSQL (CNPG)

!!! warning "Two clusters — don't mix them up"
    They use different images. `pgsql-cluster` is standard PostgreSQL 17. `immich17` has the vectorchord extension for vector search.

| Cluster       | Image                              | Use                                |
| ------------- | ---------------------------------- | ---------------------------------- |
| pgsql-cluster | cloudnative-pg/postgresql:17       | General apps (Authentik, Gatus, Homebox, Mealie, etc.) |
| immich17      | tensorchord/cloudnative-vectorchord:17 | Immich (vector search)         |

Read-write endpoint: `<cluster>-rw.database.svc.cluster.local`

Apps declare `dependsOn: [{name: cnpg-cluster, namespace: database}]` in their `ks.yaml`.

### Cache

Dragonfly (Redis-compatible) at `dragonfly-cluster.database.svc.cluster.local:6379`:

| DB | Consumer   |
| -- | ---------- |
| 0  | Default    |
| 1  | SSO (old)  |
| 2  | Immich     |
| 3  | Searxng    |
| 4  | MCP Server |
| 5  | Tracearr   |

## Secrets

All secrets live in aKeyless and sync into the cluster via ExternalSecret CRDs. Cluster-wide variables are injected through `postBuild.substituteFrom: cluster-secrets` in each app's `ks.yaml`.

## GitOps

Flux CD watches this repo and reconciles on every push.

- **Entry point**: `ks.yaml` per app — defines `dependsOn`, `postBuild` substitutions, and `components`
- **Components**: Reusable patterns in `kubernetes/components/` — volsync, cnpg, ext-auth-internal, ext-auth-external, zeroscaler

!!! danger "kubectl edits are ephemeral"
    Flux resets them on the next reconciliation. Always edit in Git, push, and reconcile.
