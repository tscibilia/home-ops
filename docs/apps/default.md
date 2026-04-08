# Default

Namespace: `default`

| App          | Storage   | Notes                                              |
| ------------ | --------- | -------------------------------------------------- |
| actual       | —         |                                                    |
| authentik    | ceph-ssd  | SSO provider, Postgres + Dragonfly, external access, cross-namespace ReferenceGrant |
| homebox      | ceph-ssd  | Postgres (cnpg component), volsync backup          |
| homepage     | —         |                                                    |
| immich       | ceph-ssd  | Postgres (immich17 cluster), Dragonfly (db2), GPU, external access |
| komga        | ceph-ssd  | External access, keda/nfs-scaler, volsync backup   |
| mealie       | ceph-ssd  | Postgres (cnpg component), external access, volsync backup |
| open-webui   | ceph-ssd  | External access, volsync backup                    |
| pairdrop     | —         |                                                    |
| radicale     | ceph-ssd  | CalDAV/CardDAV server, external access, volsync backup |
| rclone       | —         | NFS backup scaler via keda                         |
| rustfs       | ceph-ssd  | S3-compatible object storage, external access, native OIDC, volsync backup |
| searxng      | ceph-ssd  | Dragonfly (db3), volsync backup                    |
| spoolman     | ceph-ssd  | ext-auth-internal, volsync backup                  |
| thelounge    | ceph-ssd  | IRC client, volsync backup                         |
| vaultwarden  | ceph-ssd  | Password manager, external access, volsync backup  |

## Config Notes

??? note "Authentik"
    The SSO provider for the cluster. Runs its own Postgres database and Dragonfly cache. Uses a cross-namespace ReferenceGrant because other namespaces reference its outpost service (`ak-outpost-authentik-embedded-outpost.default.svc.cluster.local:9000`) in their SecurityPolicy resources.

??? note "Immich"
    Photo management with AI features. Uses the `immich17` CNPG cluster (vectorchord extension for vector search), not the general `pgsql-cluster`. Dragonfly db2 for caching. Intel i915 GPU for machine learning tasks. External access via envoy-external.

??? note "RustFS"
    S3-compatible object storage. Exposes two routes: the web console at `rustfs.${SECRET_DOMAIN}` (port 9001) and the S3 API at `r3.${SECRET_DOMAIN}` (port 9000). Both are external via envoy-external. Native OIDC login via Authentik. Replaced MinIO in April 2026.

??? note "Searxng"
    Metasearch engine using Dragonfly db3 for caching. No external access — internal only.
