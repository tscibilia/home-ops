# Docker Services

Three machines outside the cluster run Docker containers managed by [doco-cd](https://github.com/kimdre/doco-cd) — a lightweight GitOps daemon that pulls from this repo and auto-restarts services.

## How doco-cd Works

- Runs as a container on each host, watching `docker/{host}/` in this repo
- Pulls changes on a schedule and restarts affected services
- Secrets injected via aKeyless proxy (TrueNAS) or pre-configured environment
- Compose files numbered by start order (01-, 02-, etc.)

## truenas.internal

Primary NAS. Replaced the Synology in March 2026.

| Service             | Image                                          | Notes                           |
| ------------------- | ---------------------------------------------- | ------------------------------- |
| doco-cd             | ghcr.io/kimdre/doco-cd:0.76.0                 | GitOps daemon                   |
| akeyless-proxy      | (aKeyless managed)                             | Secrets provider for containers |
| tailscale           | ghcr.io/tailscale/tailscale:v1.98.3           | VPN mesh, host networking       |
| scrutiny-collector  | ghcr.io/analogj/scrutiny:v0.9.2-collector      | Reports to Scrutiny hub in cluster |
| node-exporter       | quay.io/prometheus/node-exporter:v1.11.1       | Host metrics → Prometheus       |
| fluent-bit          | cr.fluentbit.io/fluent/fluent-bit:5.0          | Container logs + error counters → Prometheus |

Repo path: `docker/truenas/`

## clonenas.internal

Backup NAS (replaced unraid). Hosts VolSync/CNPG backup repos and the NUT UPS daemon scraped by the cluster.

| Service             | Image                                          | Notes                                     |
| ------------------- | ---------------------------------------------- | ----------------------------------------- |
| matchbox            | quay.io/poseidon/matchbox:v0.11.0              | iPXE/PXE boot server for cluster nodes    |
| scrutiny-collector  | ghcr.io/analogj/scrutiny:v0.9.2-collector      | Reports SMART data to Scrutiny hub        |
| node-exporter       | quay.io/prometheus/node-exporter:v1.11.1       | Host metrics → Prometheus                 |
| fluent-bit          | cr.fluentbit.io/fluent/fluent-bit:5.0          | Container logs + error counters → Prometheus |
| nut-server          | instantlinux/nut-upsd:latest                   | NUT UPS daemon; scraped by nut-exporter in cluster |

Repo path: `docker/clonenas/`

## VPS (Pangolin)

Public VPS. Terminates Cloudflare-proxied traffic and tunnels it to the cluster via Gerbil (WireGuard). Also runs the UniFi controller.

| Service                   | Image                                                          | Notes                                        |
| ------------------------- | -------------------------------------------------------------- | -------------------------------------------- |
| pangolin                  | ghcr.io/fosrl/pangolin:1.18.4                                  | Reverse proxy / tunnel controller            |
| gerbil                    | ghcr.io/fosrl/gerbil:1.4.0                                     | WireGuard tunnel endpoint → cluster          |
| traefik                   | ghcr.io/traefik/traefik:v3.7.1                                 | HTTP entry point in front of Pangolin        |
| crowdsec                  | ghcr.io/crowdsecurity/crowdsec:v1.7.8                          | IP reputation / intrusion detection          |
| geoipupdate               | ghcr.io/maxmind/geoipupdate:v7.1.1                             | MaxMind GeoIP database updater               |
| unifi-db                  | docker.io/mongo:8.3                                            | MongoDB backend for UniFi                    |
| unifi-network-application | ghcr.io/linuxserver/unifi-network-application:10.3.58          | UniFi controller (manages UDM-Pro)           |
| node-exporter             | quay.io/prometheus/node-exporter:v1.11.1                       | Host metrics → prometheus-agent              |
| fluent-bit                | cr.fluentbit.io/fluent/fluent-bit:5.0                          | Container logs + error counters → prometheus-agent |
| prometheus-agent          | quay.io/prometheus/prometheus:v3.11.3                          | Agent mode; remote_writes to `prometheus-rw.t0m.co` |
| unifi-backup              | docker.io/restic/restic:0.18.1                                 | Daily restic backup of UniFi config → B2 (ofelia scheduler) |

Repo path: `docker/vps/`
