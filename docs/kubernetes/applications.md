# Kubernetes Applications

This page provides a comprehensive overview of all applications deployed in the cluster, organized by namespace. Each table shows dependencies and key attributes to help understand how applications are configured and interconnected.

## Legend

**Dependencies:**
- **ESO** - External Secrets Operator
- **CNPG** - CloudNativePG (PostgreSQL)
- **Redis** - Dragonfly (Redis-compatible)
- **Ceph** - Rook-Ceph storage
- **VolSync** - Backup/restore system
- **KEDA** - Auto-scaling operator
- **MinIO** - S3-compatible storage

**Attributes:**
- **DB** - Database usage (CNPG health checks)
- **OIDC** - OpenID Connect authentication
- **Auth** - Authentik SSO protection
- **NFS** - Network filesystem storage
- **GPU** - NVIDIA GPU access
- **VPN** - Multus VPN network
- **VM Rules** - VictoriaMetrics log rules
- **Reloader** - Stakater Reloader annotations

---

## Production Applications

=== "Default"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **actual** | ESO, Ceph, VolSync | volsync | VM Rules |
    | **authentik** | ESO, CNPG | cnpg | DB (pgsql-cluster), InitContainer, PodAntiAffinity, ReferenceGrant, ConfigMaps, Reloader, SSO Provider |
    | **homebox** | ESO, CNPG, Ceph, VolSync | cnpg, volsync | DB (pgsql-cluster), OIDC, SMTP |
    | **homepage** | ESO | — | Dashboard |
    | **immich** | ESO, CNPG, Redis, KEDA | cnpg | DB (immich17/PG17), Redis, OIDC, SMTP, NFS, GPU, ConfigMaps, Reloader, VM Rules |
    | **komga** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | NFS auto-scaling |
    | **mealie** | ESO, CNPG, Ceph, VolSync | cnpg, volsync | DB (pgsql-cluster), OIDC, SMTP |
    | **minio** | ESO, KEDA | keda/nfs-scaler | S3 Provider, NFS auto-scaling |
    | **open-webui** | ESO, Ceph, VolSync | volsync | OIDC |
    | **pairdrop** | ESO | — | File sharing |
    | **radicale** | ESO, Ceph, VolSync | volsync | CalDAV/CardDAV |
    | **rclone** | ESO, KEDA | keda/nfs-bkup-scaler | NFS backup auto-scaling |
    | **searxng** | Redis, ESO | — | Redis |
    | **spoolman** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, 3D printing |
    | **vaultwarden** | ESO, Ceph, VolSync | volsync | SMTP, Password manager |

=== "Database"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **cnpg-operator** | ESO | — | PostgreSQL operator |
    | **cnpg-cluster** | OpenEBS | — | General PostgreSQL cluster (pgsql-cluster) |
    | **cnpg-immich17** | OpenEBS | — | Immich PostgreSQL 17 with vectorchord |
    | **cnpg-barman-cloud** | — | — | S3 backup integration |
    | **dragonfly-operator** | — | — | Redis-compatible operator |
    | **dragonfly-cluster** | ESO | — | Redis-compatible cluster |
    | **pgadmin** | ESO, CNPG, VolSync | volsync | Database management UI |

=== "Media"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **bazarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, Subtitles |
    | **flaresolverr** | prowlarr | — | Cloudflare bypass |
    | **imagemaid** | ESO, Ceph, plex | — | Image cleanup |
    | **jellyfin** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | NFS auto-scaling, Media streaming |
    | **kometa** | ESO, Ceph, plex, VolSync | volsync | Plex metadata management |
    | **maintainerr** | ESO, Ceph, VolSync | volsync | Media maintenance |
    | **plex** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | GPU, NFS, LoadBalancer, Reloader, VM Rules, Media streaming |
    | **prowlarr** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, VPN (Multus), Reloader, Indexer management |
    | **qbittorrent** | Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | VPN (Multus), NFS, ConfigMaps, Reloader, VM Rules, Downloads |
    | **qui** | ESO, Ceph, qBittorrent, KEDA, VolSync | keda/nfs-scaler, volsync | OIDC, NFS auto-scaling |
    | **radarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, Movie automation |
    | **recyclarr** | ESO, Ceph, radarr, sonarr, VolSync | volsync | Quality profile sync |
    | **seerr** | ESO, Ceph, VolSync | volsync | Media request management |
    | **sonarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, TV automation |
    | **tautulli** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, Plex monitoring |
    | **threadfin** | ESO, Ceph, VolSync | volsync | IPTV proxy |
    | **ytptube** | ESO, Ceph, KEDA, VolSync | ext-auth-external, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, YouTube downloads |

=== "Network"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **certificates-import** | ESO | — | Import external certificates |
    | **certificates-export** | cert-manager, certificates-import | — | Export certificates to secrets |
    | **cloudflared** | ESO | — | Cloudflare Tunnel |
    | **echo** | ESO | — | Test service |
    | **envoy-gateway** | certificates-import | — | HTTPRoute ingress, ServiceMonitor |
    | **external-dns** | ESO | — | Cloudflare DNS sync, Reloader |
    | **multus** | — | — | Secondary CNI for VPN |
    | **proxy** | ESO, envoy-gateway-config | — | HTTPRoute definitions |
    | **tailscale** | ESO | — | Tailscale mesh VPN, Reloader |
    | **unifi-dns** | ESO | — | UniFi DNS integration, Reloader |

=== "Observability"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **fluent-bit** | — | — | Log forwarding to Victoria Logs |
    | **gatus** | ESO, CNPG | cnpg | DB (pgsql-cluster), Status page |
    | **grafana-operator** | — | — | Grafana operator |
    | **grafana-instance** | ESO, CNPG | cnpg | DB (pgsql-cluster), Dashboards, ServiceMonitor |
    | **guacamole-guacd** | — | — | Guacamole daemon |
    | **guacamole** | ESO, CNPG, guacamole-guacd | cnpg | DB (pgsql-cluster), OIDC, Remote desktop gateway |
    | **karma** | ESO, victoria-metrics | — | Alert dashboard |
    | **keda** | — | — | Auto-scaling operator |
    | **kite** | ESO, CNPG | cnpg | DB (pgsql-cluster), OIDC, Kubernetes dashboard |
    | **kromgo** | ESO, victoria-metrics | — | Metrics badge service |
    | **silence-operator** | — | — | Alert silencing automation |
    | **unpoller** | ESO, victoria-metrics | — | UniFi metrics exporter |
    | **victoria-logs** | ESO | ext-auth-internal | Auth, Log aggregation, OpenEBS storage |
    | **victoria-metrics** | ESO | ext-auth-internal | Auth, Metrics storage, VM Rules |
    | **blackbox-exporter** | — | — | HTTP/TCP probing |
    | **dcgm-exporter** | — | — | NVIDIA GPU metrics |
    | **plex-exporter** | — | — | Plex metrics |
    | **prowlarr-exporter** | — | — | Prowlarr metrics |
    | **pve-exporter** | ESO | — | Proxmox VE metrics |
    | **qbittorrent-exporter** | — | — | qBittorrent metrics |
    | **radarr-exporter** | — | — | Radarr metrics |
    | **seerr-exporter** | — | — | Seerr metrics |
    | **snmp-exporter** | ESO | — | SNMP device metrics (includes Synology) |
    | **sonarr-exporter** | — | — | Sonarr metrics |
    | **tautulli-exporter** | — | — | Tautulli metrics |

=== "Infrastructure"

    | Application | Namespace | Dependencies | Key Attributes |
    |-------------|-----------|--------------|----------------|
    | **actions-runner-controller** | actions-runner-system | — | GitHub Actions runners |
    | **cert-manager** | cert-manager | — | TLS certificate automation |
    | **cilium** | kube-system | — | CNI with eBPF, L2 announcements |
    | **coredns** | kube-system | — | Cluster DNS (10.43.0.10) |
    | **csi-driver-nfs** | kube-system | — | NFS CSI driver |
    | **descheduler** | kube-system | — | Pod rescheduling |
    | **external-secrets** | external-secrets | — | External Secrets Operator |
    | **flux-instance** | flux-system | — | Flux CD GitOps instance |
    | **flux-operator** | flux-system | — | Flux CD operator |
    | **generic-device-plugin** | kube-system | — | Generic device plugin |
    | **metrics-server** | kube-system | — | Resource metrics API |
    | **nvidia-device-plugin** | kube-system | — | NVIDIA GPU device plugin |
    | **openebs** | openebs-system | — | Local storage provider (openebs-hostpath) |
    | **reloader** | kube-system | — | Stakater Reloader operator |
    | **rook-ceph** | rook-ceph | — | Rook-Ceph operator |
    | **rook-ceph-cluster** | rook-ceph | — | Ceph storage cluster (RBD, CephFS) |
    | **secret-stores** | external-secrets | — | aKeyless ClusterSecretStore |
    | **snapshot-controller** | kube-system | — | Volume snapshot controller |
    | **spegel** | kube-system | — | OCI registry mirror |
    | **tuppr** | system-upgrade | — | Talos upgrade operator |
    | **volsync** | volsync-system | — | Backup/restore operator |

---

## Application Statistics

### By Namespace

- **default:** 17 applications
- **database:** 7 components
- **media:** 16 applications
- **network:** 10 applications
- **observability:** 23 applications (including 11 exporters)
- **kube-system:** 10 components
- **cert-manager:** 1 application
- **external-secrets:** 2 components
- **flux-system:** 2 components
- **openebs-system:** 1 component
- **rook-ceph:** 2 components
- **volsync-system:** 1 component
- **actions-runner-system:** 1 component
- **system-upgrade:** 1 component
- **Total:** 94 applications/components

### Technology Usage

| Technology | Count | Applications |
|------------|-------|--------------|
| **External Secrets** | 15 | authentik, cloudflared, guacamole, homebox, immich, kite, mealie, minio, pve-exporter, prowlarr, proxy, qui, snmp-exporter, tailscale, vaultwarden |
| **CNPG Database** | 9 | authentik, gatus, grafana, guacamole, homebox, immich, kite, mealie, pgadmin |
| **VolSync Backups** | 30 | actual, bazarr, homebox, jellyfin, kometa, komga, maintainerr, mealie, open-webui, pgadmin, plex, prowlarr, qbittorrent, qui, radarr, radicale, recyclarr, seerr, sonarr, spoolman, tautulli, threadfin, vaultwarden, ytptube (and more) |
| **KEDA Auto-scaling** | 13 | bazarr, immich, jellyfin, komga, minio, plex, qbittorrent, qui, radarr, rclone, sonarr, ytptube (nfs-scaler, nfs-bkup-scaler) |
| **Authentik SSO** | 11 | bazarr (int), prowlarr (int), radarr (int), sonarr (int), spoolman (int), tautulli (int), victoria-logs (int), victoria-metrics (int), ytptube (ext) |
| **OIDC Integration** | 7 | guacamole, homebox, immich, kite, mealie, open-webui, qui |
| **SMTP/Email** | 5 | homebox, immich, mealie, vaultwarden |
| **NFS Storage** | 8+ | immich, plex (media library); apps with nfs-scaler component |
| **Stakater Reloader** | 9 | authentik, external-dns, plex, prowlarr, qbittorrent, tailscale, unifi-dns |
| **VM Log Rules** | 5 | actual, immich, plex, qbittorrent, victoria-metrics |
| **NVIDIA GPU** | 2 | immich (ML), plex (transcoding) |
| **Multus VPN** | 2 | prowlarr (192.168.99.11), qbittorrent (192.168.99.10) |
| **Redis/Dragonfly** | 2 | immich, searxng |
| **MinIO S3** | 1 | minio (provider used by CNPG backups) |

### Storage Classes in Use

- **openebs-hostpath** - Local ephemeral (CNPG clusters, victoria-logs)
- **ceph-rbd** - Persistent block on HDD (media app caches)
- **ceph-ssd** - Persistent block on SSD (high-performance apps)
- **cephfs** - Shared filesystem (plex media)
- **nfs-media** - External NFS mounts (media libraries)

---

## Application Architecture Patterns

### SSO-Protected Applications

Applications using Authentik forward authentication via Envoy Gateway SecurityPolicy:

**Internal Auth** (ext-auth-internal component):
- bazarr, prowlarr, radarr, sonarr, tautulli (media apps)
- spoolman (3D printing)
- victoria-logs, victoria-metrics (observability)

**External Auth** (ext-auth-external component):
- ytptube (publicly accessible with SSO)

### Database-Backed Applications

All database applications use CloudNativePG with:
- Health checks for Flux dependency management
- Automated user/database initialization via cnpg component
- Backup to S3 via barman-cloud

**Clusters:**
- **pgsql-cluster** - General PostgreSQL cluster (used by most apps)
- **immich17** - Dedicated PG17 cluster with vectorchord extension for Immich

### Auto-Scaling Applications

KEDA auto-scaling based on NFS activity:

**nfs-scaler** - Scales down when NFS mount inactive:
- Media apps: bazarr, jellyfin, komga, plex, radarr, sonarr, ytptube
- Storage: minio, qui

**nfs-bkup-scaler** - Scales down during backup windows:
- rclone (backup sync)

### VPN-Routed Applications

Applications using secondary Multus network interfaces for VPN routing:
- **prowlarr** - 192.168.99.11/24 (indexer traffic through VPN)
- **qbittorrent** - 192.168.99.10/24 (torrent traffic through VPN gateway)

Primary eth0 interface uses Cilium for cluster communication; net1 interface routes through UniFi VPN gateway.

### Backup Strategy

VolSync handles automated backups for stateful applications:
- Scheduled snapshots to S3-compatible storage (Backblaze B2)
- Restic-based incremental backups
- Configurable retention policies
- Manual snapshot triggering via `just kube snapshot`

---

## Related Documentation

- [Kubernetes Overview](overview.md) - Architecture and GitOps workflow
- [Networking](networking.md) - CNI, ingress, and service mesh
- [VPN Networking](vpn-networking.md) - Multus secondary network configuration
- [Storage](storage.md) - Storage classes and persistent volumes
- [Secrets Management](secrets.md) - External Secrets and SOPS
- [Task Runner](../operations/task-runner.md) - Just commands for managing applications

---

## Notes

- **No NetworkPolicy resources** currently deployed (relying on Cilium security policies)
- **ServiceMonitor** usage is limited (authentik, envoy-gateway, grafana)
- Most applications use **Flux postBuild substitution** for environment-specific values
- **ReferenceGrant** only used by authentik for cross-namespace service access
- Application versions managed by **Renovate** with automated PRs
