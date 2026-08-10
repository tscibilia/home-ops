# Apps Inventory

## ⚠️ Gotchas & Interactions

- **Namespace = directory name:** Verify the `targetNamespace` in the app's `ks.yaml` before referencing it in manifests.
- **kustomization.yaml must include the new app:** When adding a new app, its `ks.yaml` path must be added to `kubernetes/apps/{namespace}/kustomization.yaml` or Flux will never reconcile it.
- **Component flags listed here:** Each app's entry notes which components it uses (kopiur, cnpg, zeroscaler, auth). Check before assuming.
- **Components go in ks.yaml:** All component references (kopiur, cnpg, auth, zeroscaler) live in `spec.components` of the Flux Kustomization (`ks.yaml`), NOT in the app's `kustomization.yaml`.
- **`[auth]` vs `[oidc]`:** `[auth]` = the `components/auth` component (tinyauth forward auth). `[oidc]` = a `PocketIDOIDCClient` CR in the app dir (native OIDC, no component). They are alternatives, not companions — see `03_networking.md`.
- **Forward-auth apps skip Gatus route monitoring:** Apps using the `auth` component sit behind a tinyauth redirect which breaks health checks. Route monitoring is disabled; service monitoring is enabled instead.

Full list by namespace. Source of truth is `kubernetes/apps/`; this file is for quick lookup.

## actions-runner-system

- actions-runner-controller

## ai

- comfyui
- hermes _(AI agent gateway — Nous Research)_ [kopiur, oidc]
- litellm _(LLM API proxy)_ [cnpg, oidc]
- litellm-operator
- llmkube _(LLM inference orchestrator)_
- memini _(AI memory/context — pgvector + semantic search)_ [cnpg]
- open-webui [kopiur, oidc]

## cert-manager

- cert-manager

## database

- cnpg _(CloudNativePG operator + clusters)_
- dragonfly _(Redis-compatible cache)_
- pgadmin [kopiur, cnpg]

## default

- actual _(budgeting)_ [kopiur, oidc]
- cetranscript _(CE Transcript — custom app)_ [cnpg]
- filebrowser _(NFS file share/drive UI — replaced boxbox)_ [kopiur, oidc]
- homebox _(inventory)_ [kopiur, cnpg, oidc]
- homepage _(dashboard)_
- immich _(photos)_ [cnpg, oidc]
- komga _(comics/manga)_ [kopiur, zeroscaler, oidc]
- mealie _(recipes)_ [kopiur, cnpg, oidc]
- pairdrop
- radicale _(CalDAV/CardDAV)_ [kopiur]
- rustfs _(S3-compatible object store)_ [kopiur, oidc]
- searxng
- smtp-relay
- spoolman _(filament tracker)_ [kopiur, auth]
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
- autobrr _(torrent automation)_ [kopiur, zeroscaler, oidc]
- bazarr _(subtitles)_ [kopiur, auth, zeroscaler]
- flaresolverr
- hometube _(yt-dlp UI)_ [kopiur, auth, zeroscaler]
- imagemaid _(Plex image cleanup)_
- jellyfin [kopiur, zeroscaler]
- kometa _(Plex metadata)_ [kopiur]
- maintainerr [kopiur]
- plex [kopiur, zeroscaler]
- prowlarr _(indexer manager)_ [kopiur, auth]
- qbittorrent [kopiur, zeroscaler]
- qui _(Plex request UI)_ [kopiur, zeroscaler, oidc]
- radarr [kopiur, auth, zeroscaler]
- recyclarr [kopiur]
- seanime _(anime library)_ [kopiur, zeroscaler]
- seerr _(Overseerr fork)_ [kopiur]
- sonarr [kopiur, auth, zeroscaler]
- tracearr _(Plex/Jellyfin tracker)_ [cnpg]

## network

- certificates
- echo
- envoy-gateway
- external-dns
- greenlight _(custom UniFi network status app)_ [auth]
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
- grafana-operator _(Grafana operator + instance)_ [cnpg, oidc]
- guacamole _(remote desktop)_ [cnpg, oidc]
- karma _(alertmanager UI)_
- kite [cnpg, oidc]
- kromgo
- kube-prometheus-stack
- prometheus-adapter _(external-metrics API for HPA)_
- scrutiny _(SMART disk monitoring)_ [kopiur]
- silence-operator
- unpoller _(UniFi metrics)_
- victoria-logs [auth]

## openebs-system

- openebs _(local hostpath CSI)_

## security

- pocket-id _(OIDC identity provider — cluster IdP, at `id.${SECRET_DOMAIN}`; operator + instance + user groups)_ [cnpg, kopiur, oidc]
- tinyauth _(forward-auth proxy backing `components/auth`, at `auth.${SECRET_DOMAIN}`)_ [oidc]

## rook-ceph

- rook-ceph _(Ceph cluster + operator)_
- ceph-csi-drivers _(Ceph-CSI Driver/OperatorConfig CRs + driver SAs/RBAC; required since rook v1.20)_

## system-upgrade

- tuppr _(Talos upgrade controller)_

## kopiur-system

- kopiur _(PVC backup/restore operator + ClusterRepository)_
- b2-sync _(kopia sync-to rclone CronJob to B2)_
