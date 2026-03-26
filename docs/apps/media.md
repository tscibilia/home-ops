# Media

Namespace: `media`

| App          | Storage   | Notes                                              |
| ------------ | --------- | -------------------------------------------------- |
| autobrr      | ceph-ssd  | Depends on qbittorrent, keda/nfs-scaler, volsync   |
| bazarr       | ceph-ssd  | Subtitle management, ext-auth-internal, keda/nfs-scaler, volsync |
| flaresolverr | —         | Captcha solver, depends on prowlarr                |
| imagemaid    | —         | Image cleanup, depends on plex                     |
| jellyfin     | ceph-ssd  | Media server, ceph storage (not NFS)               |
| kometa       | ceph-ssd  | Plex metadata manager, depends on plex, volsync    |
| maintainerr  | ceph-ssd  | Plex library cleanup, volsync backup               |
| plex         | nfs-media | External access, GPU transcoding, keda/nfs-scaler, volsync |
| prowlarr     | ceph-ssd  | Indexer manager, ext-auth-internal, volsync        |
| qbittorrent  | nfs-media | Multus VPN (192.168.99.x, VLAN 99)                |
| qui          | ceph-ssd  | qBittorrent UI, depends on qbittorrent, keda/nfs-scaler, volsync |
| radarr       | ceph-ssd  | Movie management, ext-auth-internal, keda/nfs-scaler, volsync |
| recyclarr    | —         | Quality profile sync, depends on radarr + sonarr   |
| seerr        | ceph-ssd  | Media requests, external access, volsync           |
| sonarr       | ceph-ssd  | TV management, ext-auth-internal, keda/nfs-scaler, volsync |
| tautulli     | ceph-ssd  | Plex analytics, ext-auth-internal, depends on plex, volsync |
| threadfin    | ceph-ssd  | IPTV proxy, volsync backup                         |
| ytptube      | ceph-ssd  | YouTube downloader, ext-auth-external, keda/nfs-scaler, volsync |

## Config Notes

### qBittorrent

VPN-routed via Multus secondary interface (net1) on VLAN 99 (192.168.99.0/24). All torrent traffic goes through the VPN tunnel — cluster and LAN traffic stay on the primary interface. See [Architecture — Networking](../architecture.md#physical) for the VLAN setup.

### Plex

External access via envoy-external for remote streaming. Uses Intel i915 GPU for hardware transcoding (shared with Jellyfin and Immich). Media stored on nfs-media (TrueNAS).

### Jellyfin

Uses ceph-ssd for config storage, not nfs-media. Media access is separate from Plex's NFS mount.

### ytptube

Uses `ext-auth-external` (not internal) — accessible from outside the LAN with Authentik SSO.

### recyclarr

Syncs quality profiles and custom formats to both Radarr and Sonarr. No persistent storage — config is generated from the repo on each run.
