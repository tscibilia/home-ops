# Networking

## Gateways

| Gateway | Namespace | Use case |
|---------|-----------|----------|
| `envoy-internal` | `network` | LAN-only apps |
| `envoy-external` | `network` | Internet-facing apps |

Domain variable: `${SECRET_DOMAIN}` (from `cluster-secrets` Secret).

## HTTPRoute Pattern

Routes are **inline in the HelmRelease** `values.route` block — no separate HTTPRoute manifest.

```yaml
# values section of HelmRelease
route:
  app:
    hostnames: ["${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-internal   # or envoy-external
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *port   # YAML anchor ref to port defined earlier in values
```

## SSO / Authentication (Authentik)

Add the appropriate component to the **app's `kustomization.yaml`**, not `ks.yaml`:

```yaml
# kubernetes/apps/{ns}/{app}/app/kustomization.yaml
components:
  - ../../../../components/ext-auth-internal   # internal gateway
  # or
  - ../../../../components/ext-auth-external   # external gateway
```

The component targets the HTTPRoute named `${APP}`. See `06_components.md` for override options.

**No additional ks.yaml changes needed** — `APP` must match the HTTPRoute name.

## Gatus Health Monitoring

The `gatus-sidecar` runs with `--auto-httproute --enable-httproute --enable-service`. **No annotation or action is needed** — it auto-discovers every HTTPRoute automatically.

**Exception — apps using ext-auth (Authentik forward auth):** the auth redirect means the route will never return 200. You must:
1. Disable route monitoring: `gatus.home-operations.com/enabled: "false"` on the route
2. Enable service monitoring: `gatus.home-operations.com/enabled: "true"` on the service

```yaml
# HelmRelease values — ext-auth app pattern
route:
  app:
    annotations:
      gatus.home-operations.com/enabled: "false"
    ...
service:
  app:
    annotations:
      gatus.home-operations.com/enabled: "true"
    ...
```

## DNS

- `external-dns` manages Cloudflare DNS records automatically from HTTPRoute annotations.
- Internal DNS: CoreDNS + `unifi-dns` for `.internal` hostnames.
