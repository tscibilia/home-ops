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

<!-- BEGIN GENERATED: stacks:truenas -->

| #   | Service                   | Compose file                       |
| --- | ------------------------- | ---------------------------------- |
| 01  | tailscale                 | `01-tailscale/docker-compose.yaml` |
| 02  | scrutiny (collector)      | `02-scrutiny/docker-compose.yaml`  |
| 03  | node-exporter, fluent-bit | `03-exporters/docker-compose.yaml` |

<!-- END GENERATED: stacks:truenas -->

NAS role: primary storage, NFS exports for media (`nfs-media` storage class).

### clonenas

Path: `docker/clonenas/`

<!-- BEGIN GENERATED: stacks:clonenas -->

| #   | Service                               | Compose file                       |
| --- | ------------------------------------- | ---------------------------------- |
| 01  | matchbox                              | `01-matchbox/docker-compose.yaml`  |
| 02  | scrutiny (collector)                  | `02-scrutiny/docker-compose.yaml`  |
| 03  | node-exporter, fluent-bit, nut-server | `03-exporters/docker-compose.yaml` |

<!-- END GENERATED: stacks:clonenas -->

clonenas role: backup NAS (pools: `vault`, `media`). sysadmin home: `/mnt/vault/sysadmin`. Ansible: `ansible/clonenas/playbook.yaml`.

### vps

Path: `docker/vps/`

<!-- BEGIN GENERATED: stacks:vps -->

| #   | Service                                     | Compose file                           |
| --- | ------------------------------------------- | -------------------------------------- |
| 01  | caddy-l4                                    | `01-caddy-l4/docker-compose.yaml`      |
| 02  | towonel                                     | `02-towonel/docker-compose.yaml`       |
| 03  | crowdsec (engine; host bouncer via Ansible) | `03-crowdsec/docker-compose.yaml`      |
| 04  | unifi                                       | `04-unifi/docker-compose.yaml`         |
| 05  | node-exporter, fluent-bit, prometheus-agent | `05-observability/docker-compose.yaml` |
| 06  | unifi-backup (restic→B2), ofelia scheduler  | `06-unfbkup/docker-compose.yaml`       |

<!-- END GENERATED: stacks:vps -->

VPS role: towonel hub/edge ingress gateway (DNS-only → VPS:443 → SNI split → towonel tunnel → in-cluster `envoy-external`, which terminates TLS), UniFi controller. Ansible bootstrap (`ansible/vps/playbook.yaml`) owns `/opt/doco-cd/`; doco-cd owns the `02-towonel/` and `04-unifi/` stacks via its own git clone of the repo. ([ADR-0015](../adr/0015-towonel-over-pangolin.md))

[`docker/vps/MIGRATION.md`](../../docker/vps/MIGRATION.md) — read before renaming a stack directory, editing an inline `configs:` block, debugging a missing certificate, changing ufw or `DOCKER-USER` rules, or touching `towonel-agent`. Traps and reasons only; the live architecture is in `docker/vps/README.md`.

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
