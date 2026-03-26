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
| tailscale           | tailscale/tailscale:v1.94.2                    | VPN mesh, host networking       |
| scrutiny-collector  | ghcr.io/analogj/scrutiny:v0.8.6-collector      | Reports to Scrutiny hub in cluster |

Repo path: `docker/truenas/`

## unraid.internal

Secondary storage server.

| Service             | Image                                          | Notes                    |
| ------------------- | ---------------------------------------------- | ------------------------ |
| doco-cd             | ghcr.io/kimdre/doco-cd:0.76.0                 | GitOps daemon            |
| scrutiny-collector  | ghcr.io/analogj/scrutiny:v0.8.6-collector      | 5 drives (sda–sde)      |

Repo path: `docker/unraid/`

## ai3090.internal

Dedicated GPU box for LLM inference.

| Service             | Image                                          | Notes                              |
| ------------------- | ---------------------------------------------- | ---------------------------------- |
| doco-cd             | ghcr.io/kimdre/doco-cd:0.76.0                 | GitOps daemon                      |
| scrutiny-collector  | ghcr.io/analogj/scrutiny:v0.8.6-collector      | 1 NVMe                             |
| llama-server        | ghcr.io/ggml-org/llama.cpp:server-cuda         | CUDA, Qwen3.5-35B, 8192 ctx, port 10000 |

Repo path: `docker/ai3090/`
