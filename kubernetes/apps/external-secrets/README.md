# External Secrets
Unified secrets, machine identity, credentials and keys.
Alternatives I've tried: Bitwarden and Doppler. Even though 1Password is most commonly used in the home-ops community aKeyless has it's place for my use case

## TODO: Reorganize aKeyless
```bash
---
/cloud-providers
├── /ai-apis
├── /aws-creds
├── /b2-creds
└── /ses-creds

/database
├── /cnpg-operator
└── /cnpg-users
    ├── /actual
    ├── /authentik
    ├── /immich
    └── /vaultwarden

/default
├── /actual
├── /authentik
├── /homepage
├── /immich
├── /kometa
├── /minio
├── /open-webui
├── /radicale
├── /rclone
├── /searxng
└── /vaultwarden

/deprecated
├── /arr-smaconfig
├── /ntfy
├── /obico
└── /sendgrid-creds

/kubernetes
├── /actions-runner
├── /akeyless
├── /cluster-config
├── /cluster-tls
├── /external-secrets
├── /flux-core
└── /sops

/media
├── /qbittorrent
├── /arr-apps
└── /_shared

/obvservability
├── /grafana
├── /headlamp-admin
├── /healthchecks
└── /pve-exporter

/network
├── /external-dns
├── /nginx-proxy
├── /unifi
└── /tailscale

/rook-ceph
└── {JSON SECRETS}

/talos
└── {JSON SECRETS}
```

## Other home-ops using akeyless
- https://github.com/rafaribe/home-ops (terraform)
- https://github.com/frantathefranta/home-ops (talconfig, sops, & patches)
- https://github.com/brunnels/talos-cluster (talconfig, sops, & patches)
- https://github.com/aedot/k8s-gitops (talconfig, sops, & patches)