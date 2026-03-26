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
| minio        | nfs-media | External access, keda/nfs-scaler                   |
| open-webui   | ceph-ssd  | External access, volsync backup                    |
| pairdrop     | —         |                                                    |
| radicale     | ceph-ssd  | CalDAV/CardDAV server, external access, volsync backup |
| rclone       | —         | NFS backup scaler via keda                         |
| searxng      | ceph-ssd  | Dragonfly (db3), volsync backup                    |
| spoolman     | ceph-ssd  | ext-auth-internal, volsync backup                  |
| thelounge    | ceph-ssd  | IRC client, volsync backup                         |
| vaultwarden  | ceph-ssd  | Password manager, external access, volsync backup  |

## Config Notes

### Authentik

The SSO provider for the cluster. Runs its own Postgres database and Dragonfly cache. Uses a cross-namespace ReferenceGrant because other namespaces reference its outpost service (`ak-outpost-authentik-embedded-outpost.default.svc.cluster.local:9000`) in their SecurityPolicy resources.

### Immich

Photo management with AI features. Uses the `immich17` CNPG cluster (vectorchord extension for vector search), not the general `pgsql-cluster`. Dragonfly db2 for caching. Intel i915 GPU for machine learning tasks. External access via envoy-external.

### Searxng

Metasearch engine using Dragonfly db3 for caching. No external access — internal only.
