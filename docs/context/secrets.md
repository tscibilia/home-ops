# Secrets

## ⚠️ Gotchas & Interactions

- **aKeyless path:** `/{namespace}/{app}` — most secrets are stored as a single static secret with multiple key/value pairs. Wrong path = silent empty secret, no error logged.
- **cluster-secrets scope:** `cluster-secrets` variables are cluster-wide postBuild substitutions. App-specific credentials belong in a dedicated ExternalSecret, not in cluster-secrets.
- **OIDC credentials flow the other way:** pocket-id _generates_ client credentials, so they are pushed **to** aKeyless with a `PushSecret`. Do not write an ExternalSecret that reads them — you would be reading a key nothing has written yet.

## Secret Store

All secrets come from aKeyless via the `akeyless-secret-store` ClusterSecretStore in `external-secrets` namespace ([ADR-0003](../adr/0003-external-secrets-akeyless-over-sops.md)). Every app's `ks.yaml` includes `substituteFrom: cluster-secrets` — see [ADR-0002](../adr/0002-flux-repository-conventions.md) for the full ks.yaml pattern.

## cluster-secrets Variables

Available to all apps via `substituteFrom`. Key vars:

| Var                  | Source aKeyless path          |
| -------------------- | ----------------------------- |
| `SECRET_DOMAIN`      | `/kubernetes/cluster-secrets` |
| `CEAPP_DOMAIN`       | `/kubernetes/cluster-secrets` |
| `TIMEZONE`           | `/kubernetes/cluster-secrets` |
| `TAILSCALE_MAGICDNS` | `/network/tailscale/operator` |

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

## OIDC credentials (pocket-id)

Apps with native OIDC do **not** hand-template SSO endpoints. The `PocketIDOIDCClient` CR (see `networking.md`) makes the operator create the client and write a Secret named in `spec.secret.name`. A `PushSecret` alongside it backs those generated values up to aKeyless:

```yaml
# kubernetes/apps/{ns}/{app}/app/pushsecret.yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
    name: &name ${APP}-oidc-secret
spec:
    refreshInterval: 1h
    secretStoreRefs:
        - kind: ClusterSecretStore
          name: akeyless-secret-store
    selector:
        secret:
            name: *name # the Secret the operator generated
    data:
        - match:
              secretKey: MYAPP_OIDC_CLIENT_ID # key inside the generated Secret
              remoteRef:
                  remoteKey: /security/pocket-id-clients
                  property: MYAPP_OIDC_CLIENT_ID
```

Only consume `/security/pocket-id-clients` with an ExternalSecret when a _different_ app needs another app's client credentials — e.g. `kite`, whose config template renders them into a config file.

## Password generators

`components/secrets/externalsecret.yaml` also defines three `Password` generator CRs — `password10`, `password32`, `password64`. Because that component is applied in every namespace, all three exist everywhere and are referenced by name, never redeclared per app. All use `symbols: 0`: generated values get interpolated raw into URIs (`postgresql://`, `redis://`) where a symbol would need percent-encoding.

An app seeds a credential by adding a generator entry to its own ExternalSecret's `dataFrom`, with `refreshInterval: "0"` on the spec:

```yaml
spec:
    refreshInterval: "0" # the generator is stateless — this is the ONLY thing pinning the value
    dataFrom:
        - sourceRef:
              generatorRef:
                  apiVersion: generators.external-secrets.io/v1alpha1
                  kind: Password
                  name: password32
```

### Seeded CNPG passwords

To avoid creating a CNPG role password by hand, pair the generator with a `PushSecret` that writes it to aKeyless. Two objects in the app's `app/` directory, both named `${APP}-pgpass` (see `media/airwave`): the generating ExternalSecret above, and a `PushSecret` with `updatePolicy: IfNotExists` targeting `/database/cnpg-users`, property `${APP}_postgres_password`.

`IfNotExists` is what makes this safe to leave running: after the first write aKeyless is authoritative, and a regenerated local password can never overwrite the stored one. Everything else — `components/cnpg` and the app's own ExternalSecret — keeps reading `/database/cnpg-users` as usual, so on a first deploy those reads fail until the push lands, then recover.

## aKeyless Path Conventions

| Path pattern                     | Contents                                                                                                                                                                               |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/kubernetes/cluster-secrets`    | Cluster-wide vars (domain, timezone)                                                                                                                                                   |
| `/{namespace}/{app-name}`        | App-specific secrets (e.g. `/ai/memini`, `/default/open-webui`)                                                                                                                        |
| `/database/cnpg-users`           | CNPG user passwords (all apps share one secret, fields per-app). May be seeded by a generator + `PushSecret` — see "Seeded CNPG passwords" above.                                      |
| `/security/pocket-id-clients`    | OIDC client credentials, `{APP}_OIDC_CLIENT_ID` / `{APP}_OIDC_CLIENT_SECRET` per app. **Written by `PushSecret`, not read by hand** — see "OIDC credentials" above.                    |
| `/cloud-providers/b2-creds`      | Backblaze B2 (Kopiur bucket)                                                                                                                                                           |
| `/cloud-providers/ai-apis`       | Third-party AI API keys (e.g. `FIRECRAWL_API_KEY`, used by hermes web_extract)                                                                                                         |
| `/kubernetes/github`             | GHCR pull credentials: `GHCR_USER`, `GHCR_TOKEN` — used by `ceapp-ghcr-pull` ExternalSecret (type: `kubernetes.io/dockerconfigjson`)                                                   |
| `/network/tailscale/operator`    | Tailscale operator credentials                                                                                                                                                         |
| `/network/tailscale/authkey`     | Tailscale node auth key, `TS_NODE_AUTHKEY` — read by the `ts-ai3090-node-authkey` ExternalSecret. Kept apart from the node's state secret on purpose; see `networking.md`.             |
| `/observability/gatus`           | Alertmanager: healthchecks.io URL, Pushover tokens                                                                                                                                     |
| `/observability/remote`          | Prometheus remote_write basic auth: `password_sha1_b64` (SHA1 base64 for Envoy SecurityPolicy — compute: `echo -n "PASS" \| openssl dgst -sha1 -binary \| base64`), `REMOTE_WRITE_URL` |
| `docker/vps-prometheus/username` | Prometheus basic_auth username — canonical source; used by VPS docker prometheus-agent AND K8s `prometheus-web-config` ExternalSecret                                                  |
| `docker/vps-prometheus/password` | Prometheus basic_auth password — canonical source; used by VPS docker prometheus-agent                                                                                                 |
