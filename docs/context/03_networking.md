# Networking

## ⚠️ Gotchas & Interactions

- **DNS source partitioning:** `external-dns` writes to Cloudflare; `unifi-dns` writes to UniFi LAN. The `service` source is UniFi-only. Gateway annotations create split-horizon LAN entries — not a Cloudflare conflict.
- **Two distinct auth paths:** apps with native OIDC support get a `PocketIDOIDCClient` CR in `app/` (no component). Apps without it get forward auth via the single `components/auth` component in `ks.yaml` — never just a HTTPRoute annotation. Don't apply both to one app.
- **BGP peerAddress is the VLAN5 gateway, not the router-id:** UDM-Pro BGP router-id is `192.168.1.1` but it sources connections from `192.168.5.1` (its VLAN5 interface). `CiliumBGPClusterConfig` must use `peerAddress: 192.168.5.1`. Using `192.168.1.1` will fail — Cilium rejects connections from the wrong source IP.
- **BGP CRDs are feature-gated:** They only install when `bgpControlPlane.enabled: true` in the Helm chart. Enabling it in an existing cluster via Flux causes a dry-run deadlock (KS validates `networks.yaml` before HR upgrades). Fix: `kubectl apply -n kube-system -f kubernetes/apps/kube-system/cilium/app/helmrelease.yaml --server-side --field-manager=kustomize-controller` to break the cycle.

## Gateways

| Gateway          | Namespace | Use case             |
| ---------------- | --------- | -------------------- |
| `envoy-internal` | `network` | LAN-only apps        |
| `envoy-external` | `network` | Internet-facing apps |

Domain variable: `${SECRET_DOMAIN}` (from `cluster-secrets` Secret).

## HTTPRoute Pattern

Routes are **inline in the HelmRelease** `values.route` block — no separate HTTPRoute manifest. Exception: routes needing path-level auth (e.g., `prometheus-remote-write`) use a standalone `httproute-*.yaml` file.

```yaml
# values section of HelmRelease
route:
    app:
        hostnames: ["${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}"]
        parentRefs:
            - name: envoy-internal # or envoy-external
              namespace: network
        rules:
            - backendRefs:
                  - identifier: app
                    port: *port # YAML anchor ref to port defined earlier in values
```

## SSO / Authentication (pocket-id + tinyauth)

`pocket-id` (`security` ns, at `id.${SECRET_DOMAIN}`) is the cluster IdP. `tinyauth` (`security` ns, at `auth.${SECRET_DOMAIN}`) is the forward-auth proxy in front of apps that have no OIDC support of their own. Both live in `kubernetes/apps/security/`.

### Native OIDC (preferred when the app supports it)

No component. Add a `PocketIDOIDCClient` CR to the app's `app/` directory — the pocket-id operator registers the client and writes the credentials into a Secret for you:

```yaml
# kubernetes/apps/{ns}/{app}/app/pocketidoidcclient.yaml
apiVersion: pocketid.internal/v1alpha1
kind: PocketIDOIDCClient
metadata:
    name: ${APP}
spec:
    name: MyApp
    callbackUrls:
        - "https://${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}/api/auth/callback"
    launchUrl: "https://${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}/"
    pkceEnabled: false
    allowedUserGroups: # from pocket-id/instance/pocketidusergroup.yaml
        - name: id-admin
          namespace: security
    secret:
        enabled: true
        name: ${APP}-oidc-secret
        keys: # map to whatever env var names the app expects
            clientID: MYAPP_OIDC_CLIENT_ID
            clientSecret: MYAPP_OIDC_CLIENT_SECRET
            issuerUrl: MYAPP_OIDC_ISSUER_URL
```

Requires `dependsOn: {name: pocket-id, namespace: security}` in `ks.yaml`. Available groups: `id-admin`, `id-home`, `id-family`, `id-friends`, `id-users`. See `05_secrets.md` for the companion `PushSecret` that backs the generated credentials up to aKeyless.

### Forward auth (apps with no OIDC support)

One component, used for **both** gateways — there is no internal/external split:

```yaml
# kubernetes/apps/{ns}/{app}/ks.yaml
spec:
    components:
        - ../../../../components/auth
```

Creates a `SecurityPolicy` sending ext-auth to `tinyauth.security:3000`. It targets the HTTPRoute named `${APP}`; override with `EXT_AUTH_TARGET` / `EXT_AUTH_KIND` / `EXT_AUTH_GROUP` in `postBuild.substitute`. See `06_components.md`.

## Gatus Health Monitoring

The `gatus-sidecar` runs with `--auto-httproute --enable-httproute --enable-service`. **No annotation or action is needed** — it auto-discovers every HTTPRoute automatically.

**Exception — apps using the `auth` component (tinyauth forward auth):** the auth redirect means the route will never return 200. You must:

1. Disable route monitoring: `gatus.home-operations.com/enabled: "false"` on the route
2. Enable service monitoring: `gatus.home-operations.com/enabled: "true"` on the service

```yaml
# HelmRelease values — forward-auth app pattern
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
