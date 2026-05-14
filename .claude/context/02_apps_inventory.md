# Apps Inventory

Full list by namespace. Source of truth is `kubernetes/apps/`; this file is for quick lookup.

## actions-runner-system
- actions-runner-controller

## ai
- comfyui
- llama-cpp
- mcp-servers
- open-webui
- toolhive

## cert-manager
- cert-manager

## database
- cnpg *(CloudNativePG operator + clusters)*
- dragonfly *(Redis-compatible cache)*
- pgadmin

## default
- actual *(budgeting)*
- authentik *(SSO/IdP)*
- filebrowser
- homebox *(inventory)*
- homepage *(dashboard)*
- immich *(photos)*
- komga *(comics/manga)*
- mealie *(recipes)*
- pairdrop
- radicale *(CalDAV/CardDAV)*
- rclone
- rustfs *(S3-compatible object store)*
- searxng
- smtp-relay
- spoolman *(filament tracker)*
- thelounge *(IRC)*
- vaultwarden *(Bitwarden)*

## external-secrets
- external-secrets *(operator)*
- secret-stores *(ClusterSecretStore → akeyless)*

## flux-system
- flux-instance
- flux-operator

## home-automation
- esphome
- home-assistant
- matter-server
- matterbridge
- mosquitto *(MQTT broker)*
- zwave

## kube-system
- cilium *(CNI/eBPF)*
- coredns
- csi-driver-nfs
- descheduler
- intel-gpu-resource-driver
- k8tz *(timezone injection admission controller)*
- metrics-server
- nvidia-device-plugin
- reloader
- snapshot-controller
- spegel *(OCI mirror)*

## media
- autobrr *(torrent automation)*
- bazarr *(subtitles)*
- flaresolverr
- hometube *(yt-dlp UI)*
- imagemaid *(Plex image cleanup)*
- jellyfin
- kometa *(Plex metadata)*
- maintainerr
- plex
- prowlarr *(indexer manager)*
- qbittorrent
- qui *(Plex request UI)*
- radarr
- recyclarr
- seerr *(Overseerr fork)*
- sonarr
- tracearr *(Plex/Jellyfin tracker)*

## network
- certificates
- cloudflared *(Cloudflare tunnel)*
- echo
- envoy-gateway
- external-dns
- greenlight
- multus
- tailscale
- unifi-dns

## observability
- exporters
- fluent-bit
- gatus *(health monitoring)*
- grafana
- guacamole *(remote desktop)*
- karma *(alertmanager UI)*
- keda *(event-driven autoscaler)*
- kite
- kromgo
- kube-prometheus-stack
- scrutiny *(SMART disk monitoring)*
- silence-operator
- unpoller *(UniFi metrics)*
- victoria-logs

## openebs-system
- openebs *(local hostpath CSI)*

## rook-ceph
- rook-ceph *(Ceph cluster + operator)*

## system-upgrade
- tuppr *(Talos upgrade controller)*

## volsync-system
- volsync *(PVC backup/restore)*
