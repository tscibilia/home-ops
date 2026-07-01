# Docker Hosts

## ⚠️ Gotchas & Interactions

- **aKeyless secret format:** Use JSON format (`{"key":"value"}`) for secrets with multiple key/value pairs. Use text format for single-value secrets. Wrong format = secret parsed incorrectly at runtime.
- **Docker network isolation:** Services can only communicate if on the same named Docker network. The default bridge network does not span compose projects.
- **Ansible on TrueNAS/clonenas — no `community.docker.*`:** TrueNAS SCALE's system Python is locked down; `pip` is unavailable so the `docker` SDK can't be installed. Use `ansible.builtin.shell` + raw `docker`/`docker compose` CLI instead of `docker_compose_v2`, `docker_container_info`, etc. (VPS runs Ubuntu — SDK installs fine there, so `community.docker.*` is fine on VPS.)
- **Ansible on TrueNAS/clonenas — no `ansible.builtin.cron`:** TrueNAS SCALE may not honour `/etc/cron.d`. Register cron jobs via `midclt call cronjob.create` (TrueNAS API) — see the shell task pattern in `ansible/truenas/playbook.yaml`.
- **VPS SSH:** Always use `ssh -i ~/.ssh/home-ops -p 22222 ubuntu@vps.internal`. Port 22222, key `~/.ssh/home-ops`, user `ubuntu`.
- **Ansible playbooks use `hosts: all`:** Run with `--limit <group>` (e.g. `--limit vps`, `--limit clonenas`) to avoid running against unintended hosts.

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
| 01 | matchbox | `01-matchbox/docker-compose.yaml` |
| 02 | scrutiny (collector) | `02-scrutiny/docker-compose.yaml` |
| 03 | node-exporter, fluent-bit, nut-server | `03-exporters/docker-compose.yaml` |

clonenas role: backup NAS (pools: `vault`, `media`). sysadmin home: `/mnt/vault/sysadmin`. Ansible: `ansible/clonenas/playbook.yaml`.

### vps

Path: `docker/vps/`
| # | Service | Compose file |
|---|---------|-------------|
| 01 | pangolin | `01-pangolin/docker-compose.yaml` |
| 02 | unifi | `02-unifi/docker-compose.yaml` |
| 03 | node-exporter, fluent-bit, prometheus-agent | `03-observability/docker-compose.yaml` |
| 04 | unifi-backup (restic→B2), ofelia scheduler | `04-unfbkup/docker-compose.yaml` |

VPS role: Pangolin ingress gateway (Cloudflare → VPS → Newt WireGuard tunnel → in-cluster `envoy-external`), UniFi controller. Ansible bootstrap owns `/opt/doco-cd/`; doco-cd owns the `01-pangolin/` and `02-unifi/` stacks via its own git clone of the repo.

## doco-cd GitOps Pattern

Services are numbered (`01-`, `02-`) for apply order. To add a service: create a new numbered directory with `docker-compose.yaml` and commit — doco-cd polls and applies automatically.

## aKeyless on Docker Hosts

VPS uses an aKeyless proxy sidecar (`proxy.py`) + doco-cd webhook secret provider. Secrets are injected as environment variables for `${VAR}` substitution in compose files.

**Secret mapping lives in `docker/vps/.doco-cd.yaml`** — `external_secrets` section. This is the ONLY place to declare which env vars map to which aKeyless paths. Compose files just use `${VAR}` in `environment:`. If an env var is missing at runtime, check `.doco-cd.yaml` first.

```yaml
external_secrets:
    MY_VAR:
        store_ref: akeyless
        remote_ref:
            key: docker/vps-<project>/<secret-name>
```

**Important**: aKeyless secrets on VPS Docker hosts must be individual **text** secrets (one value per secret). JSON-format secrets are not used here.
