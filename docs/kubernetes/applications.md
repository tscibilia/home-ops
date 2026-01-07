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
    | **actual** | ESO, Ceph, VolSync | volsync | VM Rules, Reloader |
    | **authentik** | ESO, CNPG | cnpg | DB (pgsql-cluster), InitContainer, PodAntiAffinity, ReferenceGrant, ConfigMaps, Reloader, SSO Provider, MinIO S3 |
    | **homebox** | ESO, CNPG, Ceph, VolSync | cnpg, volsync | DB (pgsql-cluster), OIDC, SMTP, Reloader |
    | **homepage** | ESO | — | Dashboard, Reloader |
    | **immich** | ESO, CNPG, Redis, KEDA | cnpg | DB (immich17/PG17), Redis, OIDC, SMTP, NFS, GPU, ConfigMaps, Reloader, VM Rules, VM/Prom Rules |
    | **komga** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | NFS auto-scaling, Reloader |
    | **mealie** | ESO, CNPG, Ceph, VolSync | cnpg, volsync | DB (pgsql-cluster), OIDC, SMTP, Reloader |
    | **minio** | ESO, KEDA | keda/nfs-scaler | S3 Provider, NFS auto-scaling, Reloader |
    | **open-webui** | ESO, Ceph, VolSync | volsync | OIDC, Reloader |
    | **pairdrop** | ESO | — | File sharing, Reloader |
    | **radicale** | ESO, Ceph, VolSync | volsync | CalDAV/CardDAV, Reloader |
    | **rclone** | ESO, KEDA | keda/nfs-bkup-scaler | NFS backup auto-scaling, Reloader, Backblaze B2 |
    | **searxng** | Redis, ESO | — | Redis, Reloader |
    | **spoolman** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, 3D printing, Reloader |
    | **vaultwarden** | ESO, Ceph, VolSync | volsync | SMTP, Password manager, Reloader |

=== "Database"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **cnpg-operator** | ESO | — | PostgreSQL operator |
    | **cnpg-cluster** | OpenEBS | — | General PostgreSQL cluster (pgsql-cluster), VM/Prom Rules, Grafana Dashboard, MinIO S3 |
    | **cnpg-immich17** | OpenEBS | — | Immich PostgreSQL 17 with vectorchord |
    | **cnpg-barman-cloud** | — | — | S3 backup integration |
    | **dragonfly-operator** | — | — | Redis-compatible operator |
    | **dragonfly-cluster** | ESO | — | Redis-compatible cluster, Grafana Dashboard |
    | **pgadmin** | ESO, CNPG, VolSync | volsync | Database management UI, Reloader |

=== "Media"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **bazarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, Subtitles, Reloader |
    | **flaresolverr** | prowlarr | — | Cloudflare bypass, Reloader |
    | **imagemaid** | ESO, Ceph, plex | — | Image cleanup, Reloader |
    | **jellyfin** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | NFS auto-scaling, Media streaming, Reloader |
    | **kometa** | ESO, Ceph, plex, VolSync | volsync | Plex metadata management, Reloader |
    | **maintainerr** | ESO, Ceph, VolSync | volsync | Media maintenance, Reloader |
    | **plex** | ESO, Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | GPU, NFS, LoadBalancer, Reloader, VM Rules, Media streaming |
    | **prowlarr** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, VPN (Multus), Reloader, Indexer management |
    | **qbittorrent** | Ceph, KEDA, VolSync | keda/nfs-scaler, volsync | VPN (Multus), NFS, ConfigMaps, Reloader, VM Rules, VM/Prom Rules, Downloads |
    | **qui** | ESO, Ceph, qBittorrent, KEDA, VolSync | keda/nfs-scaler, volsync | OIDC, NFS auto-scaling, Reloader |
    | **radarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, Movie automation, Reloader, VM/Prom Rules |
    | **recyclarr** | ESO, Ceph, radarr, sonarr, VolSync | volsync | Quality profile sync |
    | **seerr** | ESO, Ceph, VolSync | volsync | Media request management, Reloader |
    | **sonarr** | ESO, Ceph, KEDA, VolSync | ext-auth-internal, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, TV automation, Reloader, VM/Prom Rules |
    | **tautulli** | ESO, Ceph, VolSync | ext-auth-internal, volsync | Auth, Plex monitoring, Reloader |
    | **threadfin** | ESO, Ceph, VolSync | volsync | IPTV proxy, Reloader |
    | **ytptube** | ESO, Ceph, KEDA, VolSync | ext-auth-external, keda/nfs-scaler, volsync | Auth, NFS auto-scaling, YouTube downloads, Reloader |

=== "Network"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **certificates-import** | ESO | — | Import external certificates |
    | **certificates-export** | cert-manager, certificates-import | — | Export certificates to secrets |
    | **cloudflared** | ESO | — | Cloudflare Tunnel, Reloader, Grafana Dashboard |
    | **echo** | ESO | — | Test service |
    | **envoy-gateway** | certificates-import | — | HTTPRoute ingress, ServiceMonitor, Grafana Dashboard |
    | **external-dns** | ESO | — | Cloudflare DNS sync, Reloader, VM/Prom Rules, Grafana Dashboard |
    | **multus** | — | — | Secondary CNI for VPN |
    | **proxy** | ESO, envoy-gateway-config | — | HTTPRoute definitions |
    | **tailscale** | ESO | — | Tailscale mesh VPN, Reloader |
    | **unifi-dns** | ESO | — | UniFi DNS integration, Reloader |

=== "Observability"

    | Application | Dependencies | Components | Key Attributes |
    |-------------|--------------|------------|----------------|
    | **fluent-bit** | — | — | Log forwarding to Victoria Logs |
    | **gatus** | ESO, CNPG | cnpg | DB (pgsql-cluster), Status page, Reloader, VM/Prom Rules, Grafana Dashboard |
    | **grafana-operator** | — | — | Grafana operator |
    | **grafana-instance** | ESO, CNPG | cnpg | DB (pgsql-cluster), Dashboards, ServiceMonitor, Grafana Dashboard |
    | **guacamole-guacd** | — | — | Guacamole daemon |
    | **guacamole** | ESO, CNPG, guacamole-guacd | cnpg | DB (pgsql-cluster), OIDC, Remote desktop gateway, Reloader |
    | **karma** | ESO, victoria-metrics | — | Alert dashboard, Reloader |
    | **keda** | — | — | Auto-scaling operator |
    | **kite** | ESO, CNPG | cnpg | DB (pgsql-cluster), OIDC, Kubernetes dashboard, Reloader |
    | **kromgo** | ESO, victoria-metrics | — | Metrics badge service, Reloader |
    | **silence-operator** | — | — | Alert silencing automation |
    | **unpoller** | ESO, victoria-metrics | — | UniFi metrics exporter, Grafana Dashboard |
    | **victoria-logs** | ESO | ext-auth-internal | Auth, Log aggregation, OpenEBS storage |
    | **victoria-metrics** | ESO | ext-auth-internal | Auth, Metrics storage, VM Rules, VM/Prom Rules, Grafana Dashboard |
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
    | **cert-manager** | cert-manager | — | TLS certificate automation, VM/Prom Rules, Grafana Dashboard |
    | **cilium** | kube-system | — | CNI with eBPF, L2 announcements, Grafana Dashboard |
    | **coredns** | kube-system | — | Cluster DNS (10.43.0.10) |
    | **csi-driver-nfs** | kube-system | — | NFS CSI driver |
    | **descheduler** | kube-system | — | Pod rescheduling |
    | **external-secrets** | external-secrets | — | External Secrets Operator |
    | **flux-instance** | flux-system | — | Flux CD GitOps instance, VM/Prom Rules |
    | **flux-operator** | flux-system | — | Flux CD operator, Grafana Dashboard |
    | **generic-device-plugin** | kube-system | — | Generic device plugin |
    | **metrics-server** | kube-system | — | Resource metrics API |
    | **nvidia-device-plugin** | kube-system | — | NVIDIA GPU device plugin |
    | **openebs** | openebs-system | — | Local storage provider (openebs-hostpath) |
    | **reloader** | kube-system | — | Stakater Reloader operator |
    | **rook-ceph** | rook-ceph | — | Rook-Ceph operator, VM/Prom Rules, Grafana Dashboard |
    | **rook-ceph-cluster** | rook-ceph | — | Ceph storage cluster (RBD, CephFS) |
    | **secret-stores** | external-secrets | — | aKeyless ClusterSecretStore |
    | **snapshot-controller** | kube-system | — | Volume snapshot controller |
    | **spegel** | kube-system | — | OCI registry mirror, Grafana Dashboard |
    | **tuppr** | system-upgrade | — | Talos upgrade operator |
    | **volsync** | volsync-system | — | Backup/restore operator, VM/Prom Rules, Grafana Dashboard |

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
| **NFS Storage** | 13 | bazarr, immich, jellyfin, komga, minio, plex, qbittorrent, qui, radarr, seerr, sonarr, ytptube (NAS volume mounts) |
| **Stakater Reloader** | 43 | actual, authentik, bazarr, cloudflared, external-dns, flaresolverr, gatus, guacamole, homebox, homepage, imagemaid, immich, jellyfin, karma, kite, kometa, komga, kromgo, maintainerr, mealie, minio, open-webui, pairdrop, plex, prowlarr, qbittorrent, qui, radarr, radicale, rclone, searxng, seerr, sonarr, spoolman, tailscale, tautulli, threadfin, unifi-dns, vaultwarden, ytptube (and more in observability/exporters) |
| **VM Log Rules** | 5 | actual, immich, plex, qbittorrent, victoria-metrics |
| **VM/Prometheus Rules** | 12 | cert-manager, cnpg, external-dns, flux-instance, gatus, qbittorrent, radarr, rook-ceph, sonarr, victoria-metrics, volsync (observability exporters) |
| **Grafana Dashboards** | 16 | cert-manager, cilium, cloudflared, cnpg, dragonfly, envoy-gateway, external-dns, flux-operator, gatus, grafana, rook-ceph, spegel, unpoller, victoria-metrics, volsync (observability exporters) |
| **NVIDIA GPU** | 2 | immich (ML), plex (transcoding) |
| **Multus VPN** | 2 | prowlarr (192.168.99.11), qbittorrent (192.168.99.10) |
| **Redis/Dragonfly** | 2 | immich, searxng |
| **Backblaze B2** | 1 | rclone (offsite backup destination via VolSync) |
| **MinIO S3** | 2 | authentik (media storage), CNPG (barman-cloud backups) |

---

## Related Documentation

- [Kubernetes Overview](overview.md) - Architecture and GitOps workflow
- [Networking](networking.md) - CNI, ingress, and service mesh
- [VPN Networking](vpn-networking.md) - Multus secondary network configuration
- [Storage](storage.md) - Storage classes and persistent volumes
- [Secrets Management](secrets.md) - External Secrets with aKeyless
- [Task Runner](../operations/task-runner.md) - Just commands for managing applications

---

## Notes

- **No NetworkPolicy resources** currently deployed (relying on Cilium security policies)
- **ServiceMonitor** usage is limited (authentik, envoy-gateway, grafana)
- Most applications use **Flux postBuild substitution** for environment-specific values
- **ReferenceGrant** only used by authentik for cross-namespace service access
- Application versions managed by **Renovate** with automated PRs
