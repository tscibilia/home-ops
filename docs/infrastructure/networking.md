# Network Infrastructure

This document describes the physical network infrastructure, UniFi equipment, DNS architecture, and network services that support the Kubernetes cluster.

## Network Equipment

### UniFi UDM-Pro (192.168.5.1)

The UniFi Dream Machine Pro serves as the central network appliance providing:

- **Router/Gateway**: Primary gateway for all network traffic
- **DNS Server**: Sole DNS server for the entire network
- **Controller**: UniFi network management controller
- **Firewall**: Network security and traffic filtering
- **Ad Blocking**: First-party ad blocking with whitelist management

### Network Topology

```
Internet
    │
    ├─ UniFi UDM-Pro (192.168.5.1)
    │   ├─ Primary LAN: 192.168.5.0/24
    │   └─ Ceph Storage Network: 192.168.43.0/24
    │
    ├─ Kubernetes Nodes (Bare-Metal M70q)
    │   ├─ k8s-1: 192.168.5.211 / 192.168.43.11
    │   ├─ k8s-2: 192.168.5.212 / 192.168.43.12
    │   ├─ k8s-3: 192.168.5.213 / 192.168.43.13
    │   └─ VIP: 192.168.5.210
    │
    ├─ Synology NAS (nas.internal)
    └─ Other Infrastructure Services
```

## DNS Architecture

### DNS Resolution Flow

```
Client Request
    │
    ├─ UniFi UDM-Pro (192.168.5.1)
    │   ├─ Local DNS Records
    │   ├─ UniFi Ad Blocking Layer
    │   └─ Forward to Upstream
    │
    └─ DnsBunker DoH (Upstream Resolver)
        └─ DNS-over-HTTPS + Ad Blocking Layer
```

### DNS Components

#### UniFi DNS Server (192.168.5.1)

The sole DNS server for all network clients, providing:

- Local DNS resolution for internal services
- DNS record synchronization from Kubernetes HTTPRoutes
- First-party ad blocking (See [Ad Blocking](#ad-blocking))
- Forwarding to upstream DoH resolver

#### DnsBunker DoH Upstream

- **Purpose**: Upstream DNS resolver with DNS-over-HTTPS
- **Features**:
  - Encrypted DNS queries
  - Built-in ad blocking (second layer)
  - Privacy-focused DNS resolution
- **Integration**: Configured in UniFi UDM-Pro settings

#### unifi-dns (Kubernetes Integration)

The `unifi-dns` webhook integrates Kubernetes HTTPRoutes with UniFi DNS:

**Location**: [`kubernetes/apps/network/unifi-dns/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/network/unifi-dns)

**Function**:
- Watches HTTPRoute resources in Kubernetes
- Automatically creates DNS A records in UniFi controller
- Syncs DNS entries for services exposed via Envoy Gateway
- Enables seamless internal access to cluster services

**Example Flow**:
1. HTTPRoute created for `authentik.t0m.co`
2. unifi-dns detects the HTTPRoute
3. DNS A record created in UniFi: `authentik.t0m.co → 192.168.5.x`
4. Local clients resolve via UniFi DNS

**Configuration**: [`kubernetes/apps/network/unifi-dns/app/helmrelease.yaml`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/network/unifi-dns/app/helmrelease.yaml)

### Ad Blocking

Two-layer ad blocking strategy:

#### Layer 1: DnsBunker DoH (Upstream)
- DNS-level ad blocking at the upstream resolver
- Blocks ads before queries reach local network
- Privacy-focused blocking lists

#### Layer 2: UniFi Ad Blocking (Local)
- Built-in UniFi ad blocking mechanism
- Additional protection layer for local network
- Customizable whitelist management

**Whitelist Management**:
1. Access UniFi Portal (https://192.168.5.1)
2. Navigate to: Settings → Security → Ad Blocking
3. Add domains to whitelist as needed
4. Changes apply immediately to all clients

## Ceph Storage Network

### Dedicated Mesh Network

**Network**: 192.168.43.0/24

Rook-Ceph uses a dedicated network for storage traffic:

- **Topology**: Full mesh configuration between nodes
- **Interface**: Secondary network interface `ceph0` on each node
- **Purpose**: Isolate Ceph replication and client traffic from management network
- **Performance**: 2.5GbE dedicated bandwidth for storage

### Node Ceph Network Configuration

Each Talos node has a second NIC on the Ceph storage network:

**Network Interface Configuration**:
- Primary NIC `bond0`: 192.168.5.x (management/cluster traffic)
- Secondary NIC `ceph0`: 192.168.43.x (Ceph storage traffic)

**Node IPs**:
- k8s-1: 192.168.43.11
- k8s-2: 192.168.43.12
- k8s-3: 192.168.43.13

**Configuration Files**: [`talos/nodes/*.yaml.j2`](https://github.com/tscibilia/home-ops/tree/main/talos/nodes)

## Network Services

### LoadBalancer IP Allocation

**CiliumLoadBalancerIPPool**: 192.168.5.200-250

Kubernetes services with `type: LoadBalancer` are allocated IPs from this range via Cilium's L2 announcements:

**Key Services**:
- Kubernetes API VIP: `192.168.5.210`
- Envoy Gateway External: Allocated from pool
- Envoy Gateway Internal: Allocated from pool
- Various application LoadBalancer services (Plex: 192.168.5.235, etc.)

### UniFi Integration Services

#### unpoller (Metrics Exporter)

**Location**: [`kubernetes/apps/observability/unpoller/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/observability/unpoller/)

**Function**:
- Exports UniFi network metrics to Prometheus/VictoriaMetrics
- Monitors network device statistics, client connections, traffic patterns
- Provides visibility into UniFi infrastructure health

**Metrics Collected**:
- Network device status (switches, APs, gateway)
- Client connection statistics
- Bandwidth utilization
- Port statistics and errors

**Dashboards**: Grafana dashboards available for UniFi network monitoring

### External Access

#### Cloudflared Tunnel

**Location**: [`kubernetes/apps/network/cloudflared/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/network/cloudflared/)

**Function**:
- Cloudflare Zero Trust tunnel for external access
- Routes `*.t0m.co` traffic from internet to `envoy-external`
- No inbound firewall ports required
- Automatic TLS termination via Cloudflare

**Traffic Flow**:
```
Internet → Cloudflare Edge → Tunnel → cloudflared Pod → envoy-external → Service
```

#### Tailscale

**Location**: [`kubernetes/apps/network/tailscale/`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/network/tailscale/)

**Function**:
- Private VPN mesh network
- Secure remote access to cluster services
- Split DNS configuration for internal domain resolution

See the resolved issue: [Tailscale Split DNS](https://github.com/tscibilia/home-ops/tree/main/.github/copilot-activework.md#resolved) (2025-12-04)

## Network Security

### Firewall

UniFi UDM-Pro provides stateful firewall protection:

- Default deny for inbound traffic
- Stateful connection tracking
- Traffic filtering rules
- Geographic IP blocking (if configured)

### Traffic Segmentation

- **Management Network**: 192.168.5.0/24 (general cluster and infrastructure)
- **Ceph Storage Network**: 192.168.43.0/24 (Ceph replication and client traffic)
- **VPN Network**: 192.168.99.0/24 (VLAN 99 for Multus VPN routing)

## Network Storage

### Synology NAS (NFS)

**Storage Class**: `nfs-media`

**Configuration**: [`kubernetes/apps/kube-system/csi-driver-nfs/app/helmrelease.yaml`](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/kube-system/csi-driver-nfs/app/helmrelease.yaml)

**NFS Export**:
- Server: `nas.internal`
- Share: `/volume1/Media`
- Protocol: NFSv4
- Mount Options: `nfsvers=4,nconnect=16,hard,noatime`

**Use Cases**:
- Media storage for Plex, Jellyfin, etc.
- Shared filesystem access across pods
- Bulk file storage

### Backups

Synology NAS also serves as the backup destination for VolSync snapshots:

- Restic repositories for PVC backups
- Off-cluster backup storage
- Disaster recovery capability

## Troubleshooting

### DNS Issues

**Check UniFi DNS Server**:
1. Access UniFi Controller
2. Verify DNS settings under Settings → Networks → LAN
3. Check DNS forwarding to DnsBunker DoH

**Test DNS Resolution**:
```bash
# From a client
nslookup authentik.t0m.co 192.168.5.1

# From Kubernetes pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nslookup authentik.t0m.co
```

### unifi-dns Sync Issues

**Check unifi-dns pod logs**:
```bash
kubectl logs -n network deployment/unifi-dns -f
```

**Verify UniFi API connectivity**:
- Ensure UniFi controller is accessible
- Check credentials in ExternalSecret
- Verify network connectivity from cluster to UniFi

### Ceph Network Connectivity

**Verify secondary NIC configuration**:
```bash
eval "$(mise activate zsh)" && talosctl -n k8s-1 get addresses
```

**Test Ceph network from pod**:
```bash
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- ping 192.168.43.11
```

## Related Documentation

- [Architecture Overview](./architecture.md) - Complete infrastructure architecture
- [Rook Ceph README](https://github.com/tscibilia/home-ops/tree/main/kubernetes/apps/rook-ceph/rook-ceph/README.md) - External Ceph setup
- [Bootstrap Resources](https://github.com/tscibilia/home-ops/tree/main/bootstrap/resources.yaml.j2) - Bootstrap secrets including cluster-secrets
- [Active Work & Known Issues](https://github.com/tscibilia/home-ops/tree/main/.github/copilot-activework.md) - Current network-related tasks
