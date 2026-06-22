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
- honcho _(AI memory/context management)_
- litellm _(LLM API proxy)_
- llama-cpp
- mcp-servers
- open-webui
- toolhive

## cert-manager

- cert-manager

## database

- cnpg _(CloudNativePG operator + clusters)_
- dragonfly _(Redis-compatible cache)_
- pgadmin
- pgvector-cluster _(shared Immich + pgvector apps)_

## default

- actual _(budgeting)_
- authentik _(SSO/IdP)_
- ceapp _(CE Transcript — imagePullSecret)_
- filebrowser
- homebox _(inventory)_
- homepage _(dashboard)_
- immich _(photos)_
- komga _(comics/manga)_
- mealie _(recipes)_
- pairdrop
- radicale _(CalDAV/CardDAV)_
- rclone
- rustfs _(S3-compatible object store)_
- searxng
- smtp-relay
- spoolman _(filament tracker)_
- thelounge _(IRC)_
- vaultwarden _(Bitwarden)_

## external-secrets

- external-secrets _(operator)_
- secret-stores _(ClusterSecretStore → akeyless)_

## flux-system

- flux-instance
- flux-operator
- konflate _(local manifest rendering, replaces flux-local)_

## home-automation

- esphome
- home-assistant
- matter-server
- mosquitto _(MQTT broker)_
- otbr _(OpenThread Border Router)_
- zwave

## kube-system

- cilium _(CNI/eBPF)_
- coredns
- csi-driver-nfs
- descheduler
- intel-gpu-resource-driver
- k8tz _(timezone injection admission controller)_
- metrics-server
- nvidia-device-plugin
- reloader
- snapshot-controller
- spegel _(OCI mirror)_

## media

- agregarr _(home media aggregator dashboard)_
- autobrr _(torrent automation)_
- bazarr _(subtitles)_
- flaresolverr
- hometube _(yt-dlp UI)_
- imagemaid _(Plex image cleanup)_
- jellyfin
- kometa _(Plex metadata)_
- maintainerr
- plex
- prowlarr _(indexer manager)_
- qbittorrent
- qui _(Plex request UI)_
- radarr
- recyclarr
- seerr _(Overseerr fork)_
- sonarr
- tracearr _(Plex/Jellyfin tracker)_

## network

- certificates
- echo
- envoy-gateway
- external-dns
- greenlight _(custom UniFi network status app)_
- multus
- pangolin-operator _(VPS tunnel ingress via Newt/WireGuard)_
- tailscale
- unifi-dns

## observability

- exporters _(blackbox, nut, plex, prowlarr, qbittorrent, radarr, seerr, sonarr)_
- fluent-bit
- gatus _(health monitoring)_
- grafana
- guacamole _(remote desktop)_
- karma _(alertmanager UI)_
- kite
- kromgo
- kube-prometheus-stack
- prometheus-adapter _(external-metrics API for HPA, replaces keda)_
- scrutiny _(SMART disk monitoring)_
- silence-operator
- unpoller _(UniFi metrics)_
- victoria-logs

## openebs-system

- openebs _(local hostpath CSI)_

## rook-ceph

- rook-ceph _(Ceph cluster + operator)_
- ceph-csi-drivers _(Ceph-CSI Driver/OperatorConfig CRs + driver SAs/RBAC; required since rook v1.20)_

## system-upgrade

- tuppr _(Talos upgrade controller)_

## volsync-system

- kopia _(VolSync backup repository web UI)_
- volsync _(PVC backup/restore — volsync-perfectra1n)_
