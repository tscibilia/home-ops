# Apps Inventory

## ⚠️ Gotchas & Interactions

- **Namespace = directory name:** Verify the `targetNamespace` in the app's `ks.yaml` before referencing it in manifests.
- **kustomization.yaml must include the new app:** When adding a new app, its `ks.yaml` path must be added to `kubernetes/apps/{namespace}/kustomization.yaml` or Flux will never reconcile it.
- **Component flags listed here:** Each app's entry notes which components it uses (kopiur, cnpg, zeroscaler, ext-auth). Check before assuming.
- **Components go in ks.yaml:** All component references (kopiur, cnpg, ext-auth, zeroscaler) live in `spec.components` of the Flux Kustomization (`ks.yaml`), NOT in the app's `kustomization.yaml`.
- **ext-auth apps skip Gatus route monitoring:** Apps using ext-auth have Authentik forward auth which breaks health checks. Route monitoring is disabled; service monitoring is enabled instead.

Full list by namespace. Source of truth is `kubernetes/apps/`; this file is for quick lookup.

## actions-runner-system

- actions-runner-controller

## ai

- comfyui
- hermes _(AI agent gateway — Nous Research)_
- litellm _(LLM API proxy)_ [cnpg]
- llama-cpp
- llmkube _(LLM inference orchestrator)_
- mcp-servers
- memini _(AI memory/context — pgvector + semantic search)_ [cnpg]
- open-webui [kopiur]
- toolhive

## cert-manager

- cert-manager

## database

- cnpg _(CloudNativePG operator + clusters)_
- dragonfly _(Redis-compatible cache)_
- pgadmin [kopiur, cnpg]

## default

- actual _(budgeting)_ [kopiur]
- authentik _(SSO/IdP)_ [cnpg]
- boxbox _(NFS file share/drive UI)_ [kopiur]
- cetranscript _(CE Transcript — custom app)_ [cnpg]
- homebox _(inventory)_ [kopiur, cnpg]
- homepage _(dashboard)_
- immich _(photos)_ [kopiur, cnpg]
- komga _(comics/manga)_ [kopiur, zeroscaler]
- mealie _(recipes)_ [kopiur, cnpg]
- pairdrop
- radicale _(CalDAV/CardDAV)_ [kopiur]
- rclone [zeroscaler]
- rustfs _(S3-compatible object store)_ [kopiur]
- searxng
- smtp-relay
- spoolman _(filament tracker)_ [kopiur, ext-auth-internal]
- thelounge _(IRC)_ [kopiur]
- vaultwarden _(Bitwarden)_ [kopiur]

## external-secrets

- external-secrets _(operator)_
- secret-stores _(ClusterSecretStore → akeyless)_

## flux-system

- flux-instance
- flux-operator
- konflate _(local manifest rendering, replaces flux-local)_

## home-automation

- esphome [kopiur]
- home-assistant [kopiur]
- matter-server [kopiur]
- mosquitto _(MQTT broker)_
- otbr _(OpenThread Border Router)_ [kopiur]
- zwave [kopiur]

## kube-system

- cilium _(CNI/eBPF)_
- coredns
- csi-driver-nfs
- descheduler
- generic-device-plugin _(TUN/DRI device exposure DaemonSet)_
- intel-gpu-resource-driver
- k8tz _(timezone injection admission controller)_
- metrics-server
- nvidia-device-plugin
- reloader
- snapshot-controller
- spegel _(OCI mirror)_

## media

- agregarr _(home media aggregator dashboard)_ [kopiur]
- autobrr _(torrent automation)_ [kopiur, zeroscaler]
- bazarr _(subtitles)_ [kopiur, ext-auth-internal, zeroscaler]
- flaresolverr
- hometube _(yt-dlp UI)_ [kopiur, ext-auth-external, zeroscaler]
- imagemaid _(Plex image cleanup)_
- jellyfin [kopiur, zeroscaler]
- kometa _(Plex metadata)_ [kopiur]
- maintainerr [kopiur]
- plex [kopiur, zeroscaler]
- prowlarr _(indexer manager)_ [kopiur, ext-auth-internal]
- qbittorrent [kopiur, zeroscaler]
- qui _(Plex request UI)_ [kopiur, zeroscaler]
- radarr [kopiur, ext-auth-internal, zeroscaler]
- recyclarr [kopiur]
- seerr _(Overseerr fork)_ [kopiur]
- sonarr [kopiur, ext-auth-internal, zeroscaler]
- tracearr _(Plex/Jellyfin tracker)_ [cnpg]

## network

- certificates
- echo
- envoy-gateway
- external-dns
- greenlight _(custom UniFi network status app)_ [ext-auth-internal]
- multus
- pangolin-operator _(VPS tunnel ingress via Newt/WireGuard)_
- tailscale
- unifi-dns

## observability

- exporters/blackbox-exporter
- exporters/nut-exporter
- exporters/plex-exporter
- exporters/prowlarr-exporter
- exporters/qbittorrent-exporter
- exporters/radarr-exporter
- exporters/seerr-exporter
- exporters/sonarr-exporter
- fluent-bit
- gatus _(health monitoring)_ [cnpg]
- grafana [cnpg]
- guacamole _(remote desktop)_ [cnpg]
- karma _(alertmanager UI)_
- kite [cnpg]
- kromgo
- kube-prometheus-stack
- prometheus-adapter _(external-metrics API for HPA)_
- scrutiny _(SMART disk monitoring)_ [kopiur]
- silence-operator
- unpoller _(UniFi metrics)_
- victoria-logs [ext-auth-internal]

## openebs-system

- openebs _(local hostpath CSI)_

## rook-ceph

- rook-ceph _(Ceph cluster + operator)_
- ceph-csi-drivers _(Ceph-CSI Driver/OperatorConfig CRs + driver SAs/RBAC; required since rook v1.20)_

## system-upgrade

- tuppr _(Talos upgrade controller)_

## kopiur-system

- kopiur _(PVC backup/restore operator + ClusterRepository)_
