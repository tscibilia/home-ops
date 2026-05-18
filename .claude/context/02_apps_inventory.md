# Apps Inventory

## ⚠️ Gotchas & Interactions

- **Namespace = directory name:** Verify the the `targetNamespace` in the app's `ks.yaml` before referencing it in manifests.
- **kustomization.yaml must include the new app:** When adding a new app, its `ks.yaml` path must be added to `kubernetes/apps/{namespace}/kustomization.yaml` or Flux will never reconcile it.
- **Component flags listed here:** Each app's entry notes which components it uses (volsync, cnpg, zeroscaler). Check before assuming.

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
- mosquitto *(MQTT broker)*
- otbr *(OpenThread Border Router)*
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
- agregarr *(home media aggregator dashboard)*
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
- echo
- envoy-gateway
- external-dns
- greenlight *(custom UniFi network status app)*
- multus
- pangolin-operator *(VPS tunnel ingress via Newt/WireGuard)*
- tailscale
- unifi-dns

## observability
- exporters
- fluent-bit
- gatus *(health monitoring)*
- grafana
- guacamole *(remote desktop)*
- karma *(alertmanager UI)*
- kite
- kromgo
- kube-prometheus-stack
- prometheus-adapter *(external-metrics API for HPA, replaces keda)*
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
