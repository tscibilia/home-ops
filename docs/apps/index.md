# Applications

All apps are deployed via Flux CD. Each has a `ks.yaml` entry point in `kubernetes/apps/{namespace}/{app}/`.

## Adding an App

1. Copy an existing app directory, update the YAML anchor (`name: &app`) and namespace
2. Add secrets to aKeyless → reference them in `externalsecret.yaml`
3. Validate locally: `just kube apply-ks <ns> <app>`
4. Push and reconcile: `just kube ks-reconcile <ns> <app>`

Reusable components live in `kubernetes/components/`:

| Component          | What it does                                    |
| ------------------ | ----------------------------------------------- |
| volsync            | PVC backup/restore (needs `APP` + `VOLSYNC_CAPACITY` substitutions) |
| cnpg               | DB user init CronJob + ExternalSecret           |
| ext-auth-internal  | Authentik SSO for internal apps                 |
| ext-auth-external  | Authentik SSO for external apps                 |
| keda               | ScaledObject auto-scaling                       |

Include via `components: [../../../../components/<name>]` in `ks.yaml`.

## By Namespace

| Namespace                                  | Apps | Purpose                                    |
| ------------------------------------------ | ---- | ------------------------------------------ |
| [default](default.md)                      | 16   | SSO, dashboard, photos, recipes, passwords |
| [media](media.md)                          | 18   | Plex, *arr stack, downloads                |
| [database](database.md)                    | 3    | CNPG clusters, Dragonfly, pgAdmin          |
| [home-automation](home-automation.md)      | 5    | Home Assistant, MQTT, ESPHome, Z-Wave      |
| [observability](observability.md)          | 14   | Prometheus, Grafana, logs, alerting        |
| [network](network.md)                      | 9    | Envoy, Cloudflared, DNS, Tailscale         |
| [system](system.md)                        | 19   | Cilium, Flux, Rook-Ceph, cert-manager     |
