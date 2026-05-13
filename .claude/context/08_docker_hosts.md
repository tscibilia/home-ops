# Docker Hosts

Non-Kubernetes Docker hosts managed via **doco-cd** (GitOps pull-based CD). Each host runs a cron that pulls from this repo and applies `docker compose up -d`.

## Hosts

### truenas
Path: `docker/truenas/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | tailscale | `01-tailscale/docker-compose.yaml` |
| 02 | scrutiny (collector) | `02-scrutiny/docker-compose.yaml` |

NAS role: primary storage, NFS exports for media (`nfs-media` storage class).

### clonenas
Path: `docker/clonenas/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | scrutiny (collector) | `01-scrutiny/docker-compose.yaml` |
| 02 | matchbox | `02-matchbox/docker-compose.yaml` |

clonenas role: backup NAS (pools: `vault`, `media`). sysadmin home: `/mnt/vault/data/sysadmin`. Ansible: `ansible/clonenas/playbook.yaml`.

### unraid
Path: `docker/unraid/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | scrutiny (collector) | `01-scrutiny/docker-compose.yaml` |
| 02 | matchbox | `02-matchbox/docker-compose.yaml` |

Unraid role: secondary/backup NFS, GPU workloads (ai3090 node). **Archived** — replaced by clonenas.

### vps
Path: `docker/vps/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | pangolin | `01-pangolin/docker-compose.yaml` |
| 02 | unifi | `02-unifi/docker-compose.yaml` |

VPS role: Cloudflare tunnel exit node, UniFi controller, Pangolin tunnel proxy.

## doco-cd GitOps Pattern

Services are numbered (`01-`, `02-`) for apply order. To add a service: create a new numbered directory with `docker-compose.yaml` and commit — doco-cd polls and applies automatically.

## aKeyless on Docker Hosts

TrueNAS and VPS hosts use an aKeyless proxy sidecar (`proxy.py`) in the doco-cd container to serve secrets to compose services. Secrets are injected as environment variables via the proxy endpoint, not stored on disk.

**Important**: aKeyless secrets on Docker hosts use JSON-format secrets (not plain text). The proxy parses the JSON and exposes individual fields.
