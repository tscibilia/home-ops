# Secrets

## ⚠️ Gotchas & Interactions

- **aKeyless path:** `/{namespace}/{app}` — most secrets are stored as a single static secret with multiple key/value pairs. Wrong path = silent empty secret, no error logged.
- **cluster-secrets scope:** `cluster-secrets` variables are cluster-wide postBuild substitutions. App-specific credentials belong in a dedicated ExternalSecret, not in cluster-secrets.

## Secret Store

All secrets come from aKeyless via the `akeyless-secret-store` ClusterSecretStore in `external-secrets` namespace. Every app's `ks.yaml` includes `substituteFrom: cluster-secrets` — see `07_flux_conventions.md` for the full ks.yaml pattern.

## cluster-secrets Variables

Available to all apps via `substituteFrom`. Key vars:

| Var | Source aKeyless path |
|-----|---------------------|
| `SECRET_DOMAIN` | `/kubernetes/cluster-secrets` |
| `TIMEZONE` | `/kubernetes/cluster-secrets` |
| `TAILSCALE_MAGICDNS` | `/network/tailscale/operator` |
| `AWS_VOLSYNC_BUCKET` | `/cloud-providers/b2-creds` |

## ExternalSecret Pattern

Standard app secret (for app-specific credentials):
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: &name ${APP}-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: akeyless-secret-store
  target:
    name: *name
    template:
      data:
        MY_KEY: "{{ .MY_FIELD }}"
  dataFrom:
    - extract:
        key: /kubernetes/<app-path>
```

## aKeyless Path Conventions

| Path pattern | Contents |
|-------------|----------|
| `/kubernetes/cluster-secrets` | Cluster-wide vars (domain, timezone) |
| `/kubernetes/<app-name>` | App-specific secrets |
| `/database/cnpg-users` | CNPG user passwords (all apps share one secret, fields per-app) |
| `/cloud-providers/b2-creds` | Backblaze B2 (VolSync bucket) |
| `/network/tailscale/operator` | Tailscale operator credentials |
| `/observability/gatus` | Alertmanager: healthchecks.io URL, Pushover tokens |
| `/observability/remote` | Prometheus remote_write basic auth: `username`, `password`, `password_sha1_b64` (SHA1 base64 for Envoy SecurityPolicy — compute: `echo -n "PASS" \| openssl dgst -sha1 -binary \| base64`), `REMOTE_WRITE_URL` |
| `docker/vps-prometheus/username` | VPS prometheus-agent basic_auth username (text secret, mirrors `/observability/remote` username) |
| `docker/vps-prometheus/password` | VPS prometheus-agent basic_auth password (text secret, mirrors `/observability/remote` password) |

