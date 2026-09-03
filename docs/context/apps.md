# Apps Inventory

## ⚠️ Gotchas & Interactions

- **Namespace = directory name:** Verify the `targetNamespace` in the app's `ks.yaml` before referencing it in manifests.
- **kustomization.yaml must include the new app:** When adding a new app, its `ks.yaml` path must be added to `kubernetes/apps/{namespace}/kustomization.yaml` or Flux will never reconcile it.
- **Component flags listed here:** Each app's entry notes which app components it uses (kopiur, cnpg, zeroscaler, auth). Check before assuming.
- **App components go in ks.yaml:** The four per-app components (`auth`, `cnpg`, `kopiur/backup`, `zeroscaler`) live in `spec.components` of the Flux Kustomization (`ks.yaml`), never in the app's `kustomization.yaml`.
- **Namespace components are not listed here:** `alerts`, `secrets` and `kopiur/secret` are declared once per namespace in `kubernetes/apps/{ns}/kustomization.yaml` and apply to every app in it. The `[flags]` below track app components only — see `components.md`.
- **`[auth]` vs `[oidc]`:** `[auth]` = the `components/auth` component (tinyauth forward auth). `[oidc]` = a `PocketIDOIDCClient` CR in the app dir (native OIDC, no component). They are alternatives, not companions — see `networking.md`.
- **Forward-auth apps skip Gatus route monitoring:** Apps using the `auth` component sit behind a tinyauth redirect which breaks health checks. Route monitoring is disabled; service monitoring is enabled instead.

Full list by namespace. The source of truth is `kubernetes/apps/`; the list below is rendered from it by `just docs generate` and checked by `just docs test`. Don't hand-edit it — the one exception is the `_(description)_` after an app name, which is hand-written and preserved across regenerations.

<!-- BEGIN GENERATED: apps -->

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
- pgadmin [kopiur]

## default

- actual _(budgeting)_ [kopiur, oidc]
- cetranscript _(CE Transcript — custom app)_ [cnpg]
- filebrowser _(NFS file share/drive UI)_ [kopiur, oidc]
- homebox _(inventory)_ [kopiur, cnpg, oidc]
- homepage _(dashboard)_ [oidc]
- immich _(photos)_ [cnpg, oidc]
- komga _(comics/manga)_ [kopiur, zeroscaler, oidc]
- mealie _(recipes)_ [kopiur, cnpg, oidc]
- obsidian-couchdb _(CouchDB for Obsidian LiveSync)_ [kopiur]
- pairdrop _(airdrop alternative)_
- radicale _(CalDAV/CardDAV)_ [kopiur]
- rustfs _(S3-compatible object store)_ [kopiur, oidc]
- searxng _(metasearch engine)_
- smtp-relay
- spoolman _(filament tracker)_ [kopiur, auth]
- thelounge _(IRC)_ [kopiur]
- vaultwarden _(Bitwarden)_ [kopiur]

## external-secrets

- external-secrets
- secret-stores _(ClusterSecretStore → akeyless)_

## flux-system

- flux-instance
- flux-operator
- konflate _(local manifest rendering)_

## home-automation

- esphome [kopiur]
- home-assistant [kopiur]
- matter-server [kopiur]
- mosquitto _(MQTT broker)_
- otbr _(OpenThread Border Router)_ [kopiur]
- zwave [kopiur]

## kopiur-system

- b2-sync _(kopia sync-to rclone CronJob to B2)_
- kopiur _(PVC backup/restore operator)_

## kube-system

- cilium _(CNI/eBPF)_
- coredns
- csi-driver-nfs
- descheduler _(k8s eviction rules)_
- generic-device-plugin _(TUN/DRI device exposure DaemonSet)_
- intel-gpu-resource-driver
- k8tz _(timezone injection admission controller)_
- metrics-server
- nvidia-device-plugin
- ocharted _(private OCI chart proxy)_
- reloader
- snapshot-controller
- spegel _(OCI mirror)_

## media

- agregarr _(home media aggregator dashboard)_ [kopiur]
- airwave [cnpg]
- autobrr _(torrent automation)_ [kopiur, zeroscaler, oidc]
- bazarr _(subtitles)_ [kopiur, auth, zeroscaler]
- cleanrr
- flaresolverr _(solves cloudflare captcha)_
- hometube _(yt-dlp UI)_ [kopiur, auth, zeroscaler]
- imagemaid _(Plex image cleanup)_
- jellyfin [kopiur, zeroscaler]
- kometa _(Plex metadata)_ [kopiur]
- maintainerr _(media deletion rules)_ [kopiur]
- plex [kopiur, zeroscaler]
- prowlarr _(indexer manager)_ [kopiur, auth]
- qbittorrent [kopiur, zeroscaler]
- qui _(qbittorrent UI)_ [kopiur, zeroscaler, oidc]
- radarr [kopiur, auth, zeroscaler]
- recyclarr _(auto-sync TRaSH Guides)_ [kopiur]
- seanime _(anime library)_ [kopiur, zeroscaler]
- seerr _(Plex request UI)_ [kopiur]
- sonarr [kopiur, auth, zeroscaler]
- tracearr _(Plex/Jellyfin tracker)_ [cnpg]

## network

- certificates
- echo
- envoy-gateway
- external-dns
- greenlight _(custom UniFi network status app)_ [auth]
- multus
- tailscale
- towonel-agent _(VPS tunnel ingress via iroh QUIC — see ADR-0015)_
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
- karma _(alertmanager UI)_
- kite [cnpg, oidc]
- kromgo
- kube-prometheus-stack
- prometheus-adapter _(external-metrics API for HPA)_
- scrutiny _(SMART disk monitoring)_ [kopiur]
- silence-operator
- termix _(remote SSH and RDP console)_ [kopiur, oidc]
- unpoller _(UniFi metrics)_
- victoria-logs [auth]

## openebs-system

- openebs _(local hostpath CSI)_

## rook-ceph

- ceph-csi-drivers _(Ceph-CSI Driver/OperatorConfig CRs + driver SAs/RBAC; required since rook v1.20)_
- rook-ceph _(Ceph cluster + operator)_

## security

- pocket-id _(OIDC identity provider)_ [kopiur, cnpg]
- tinyauth _(forward-auth proxy)_ [oidc]

## system-upgrade

- tuppr _(Talos upgrade controller)_

<!-- END GENERATED: apps -->
