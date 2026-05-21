# Docker Hosts

## ⚠️ Gotchas & Interactions

- **aKeyless secret format:** Use JSON format (`{"key":"value"}`) for secrets with multiple key/value pairs. Use text format for single-value secrets. Wrong format = secret parsed incorrectly at runtime.
- **Docker network isolation:** Services can only communicate if on the same named Docker network. The default bridge network does not span compose projects.
- **Ansible on TrueNAS/clonenas — no `community.docker.*`:** TrueNAS SCALE's system Python is locked down; `pip` is unavailable so the `docker` SDK can't be installed. Use `ansible.builtin.shell` + raw `docker`/`docker compose` CLI instead of `docker_compose_v2`, `docker_container_info`, etc. (VPS runs Ubuntu — SDK installs fine there, so `community.docker.*` is fine on VPS.)
- **Ansible on TrueNAS/clonenas — no `ansible.builtin.cron`:** TrueNAS SCALE may not honour `/etc/cron.d`. Register cron jobs via `midclt call cronjob.create` (TrueNAS API) — see the shell task pattern in `ansible/truenas/playbook.yaml`.

Non-Kubernetes Docker hosts managed via **doco-cd** (GitOps pull-based CD). Each host runs a cron that pulls from this repo and applies `docker compose up -d`.

## Hosts

### truenas
Path: `docker/truenas/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | tailscale | `01-tailscale/docker-compose.yaml` |
| 02 | scrutiny (collector) | `02-scrutiny/docker-compose.yaml` |
| 03 | node-exporter, fluent-bit | `03-exporters/docker-compose.yaml` |

NAS role: primary storage, NFS exports for media (`nfs-media` storage class).

### clonenas
Path: `docker/clonenas/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | scrutiny (collector) | `01-scrutiny/docker-compose.yaml` |
| 02 | matchbox | `02-matchbox/docker-compose.yaml` |
| 03 | node-exporter, fluent-bit | `03-exporters/docker-compose.yaml` |

clonenas role: backup NAS (pools: `vault`, `media`). sysadmin home: `/mnt/vault/sysadmin`. Ansible: `ansible/clonenas/playbook.yaml`.

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
| 03 | node-exporter, fluent-bit, prometheus-agent | `03-observability/docker-compose.yaml` |

VPS role: Pangolin ingress gateway (Cloudflare → VPS → Newt WireGuard tunnel → in-cluster `envoy-external`), UniFi controller. Ansible bootstrap owns `/opt/doco-cd/`; doco-cd owns the `01-pangolin/` and `02-unifi/` stacks via its own git clone of the repo.

## doco-cd GitOps Pattern

Services are numbered (`01-`, `02-`) for apply order. To add a service: create a new numbered directory with `docker-compose.yaml` and commit — doco-cd polls and applies automatically.

## aKeyless on Docker Hosts

TrueNAS and VPS hosts use an aKeyless proxy sidecar (`proxy.py`) in the doco-cd container to serve secrets to compose services. Secrets are injected as environment variables via the proxy endpoint, not stored on disk.

**Important**: aKeyless secrets on Docker hosts use JSON-format secrets (not plain text). The proxy parses the JSON and exposes individual fields.
