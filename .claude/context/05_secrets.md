# Secrets

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

