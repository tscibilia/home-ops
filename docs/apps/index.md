# Applications

All apps are deployed via Flux CD. Each has a `ks.yaml` entry point in `kubernetes/apps/{namespace}/{app}/`.

## Adding an App

Use the `/add-app` AI skill — it interactively scaffolds all manifests from scratch.

1. Run `/add-app` in Claude Code — it prompts for app name, namespace, helm chart type, ingress, auth, and optional features (VolSync, CNPG, zeroscaler, Gatus), then generates all files
2. Add secrets to aKeyless at the path referenced in `externalsecret.yaml`
3. Fill in `{IMAGE_REPO}` and `{IMAGE_TAG}` in `helmrelease.yaml` (add Renovate annotation)
4. Validate

Reusable components live in `kubernetes/components/`:

| Component          | What it does                                    |
| ------------------ | ----------------------------------------------- |
| volsync            | PVC backup/restore (needs `APP` + `VOLSYNC_CAPACITY` substitutions) |
| cnpg               | DB user init CronJob + ExternalSecret           |
| ext-auth-internal  | Authentik SSO for internal apps                 |
| ext-auth-external  | Authentik SSO for external apps                 |
| zeroscaler         | Native HPA scale-to-zero based on Prometheus `probe_success` (replaces keda) |

Include via `components: [../../../../components/<name>]` in `ks.yaml`.

## By Namespace

| Namespace                                  | Apps | Purpose                                    |
| ------------------------------------------ | ---- | ------------------------------------------ |
| [ai](ai.md)                                | 7    | LLMs, image gen, MCP tools                 |
| [default](default.md)                      | 17   | SSO, dashboard, photos, recipes, passwords |
| [media](media.md)                          | 19   | Plex, *arr stack, downloads                |
| [database](database.md)                    | 3    | CNPG clusters, Dragonfly, pgAdmin          |
| [home-automation](home-automation.md)      | 6    | Home Assistant, MQTT, ESPHome, Matter/Thread |
| [observability](observability.md)          | 14   | Prometheus, Grafana, logs, alerting        |
| [network](network.md)                      | 9    | Envoy, Pangolin, DNS, Tailscale            |
| [system](system.md)                        | 21   | Cilium, Flux, Rook-Ceph, cert-manager     |
