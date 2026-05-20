# Networking

## ⚠️ Gotchas & Interactions

- **DNS source partitioning:** `external-dns` writes to Cloudflare; `unifi-dns` writes to UniFi LAN. The `service` source is UniFi-only. Gateway annotations create split-horizon LAN entries — not a Cloudflare conflict.
- **SSO requires a component:** Authentik SSO requires `ext-auth-internal` or `ext-auth-external` component in `ks.yaml`, not just a HTTPRoute annotation.
- **BGP peerAddress is the VLAN5 gateway, not the router-id:** UDM-Pro BGP router-id is `192.168.1.1` but it sources connections from `192.168.5.1` (its VLAN5 interface). `CiliumBGPClusterConfig` must use `peerAddress: 192.168.5.1`. Using `192.168.1.1` will fail — Cilium rejects connections from the wrong source IP.
- **BGP CRDs are feature-gated:** They only install when `bgpControlPlane.enabled: true` in the Helm chart. Enabling it in an existing cluster via Flux causes a dry-run deadlock (KS validates `networks.yaml` before HR upgrades). Fix: `kubectl apply -n kube-system -f kubernetes/apps/kube-system/cilium/app/helmrelease.yaml --server-side --field-manager=kustomize-controller` to break the cycle.

## Gateways

| Gateway | Namespace | Use case |
|---------|-----------|----------|
| `envoy-internal` | `network` | LAN-only apps |
| `envoy-external` | `network` | Internet-facing apps |

Domain variable: `${SECRET_DOMAIN}` (from `cluster-secrets` Secret).

## Known External Routes

| Hostname | Path | Backend | File |
|----------|------|---------|------|
| `prometheus-rw.${SECRET_DOMAIN}` | `/api/v1/write` | `kube-prometheus-stack-prometheus:9090` | `observability/kube-prometheus-stack/app/httproute.yaml` |

Protected by basic auth via `prometheus-web-config` secret (bcrypt, sourced from `/observability/remote` in aKeyless).

## HTTPRoute Pattern

Routes are **inline in the HelmRelease** `values.route` block — no separate HTTPRoute manifest. Exception: routes needing path-level auth (e.g., `prometheus-remote-write`) use a standalone `httproute-*.yaml` file.

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
