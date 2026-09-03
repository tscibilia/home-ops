# Networking

## ⚠️ Gotchas & Interactions

- **DNS source partitioning:** `external-dns` writes to Cloudflare; `unifi-dns` writes to UniFi LAN. The `service` source is UniFi-only. Gateway annotations create split-horizon LAN entries — not a Cloudflare conflict.
- **Two distinct auth paths:** apps with native OIDC support get a `PocketIDOIDCClient` CR in `app/` (no component). Apps without it get forward auth via the single `components/auth` component in `ks.yaml` — never just a HTTPRoute annotation. Don't apply both to one app.
- **BGP peerAddress is the VLAN5 gateway, not the router-id:** UDM-Pro BGP router-id is `192.168.1.1` but it sources connections from `192.168.5.1` (its VLAN5 interface). `CiliumBGPClusterConfig` must use `peerAddress: 192.168.5.1`. Using `192.168.1.1` will fail — Cilium rejects connections from the wrong source IP.
- **No HTTP/3 on either gateway, and don't re-add it:** the `envoy` ClientTrafficPolicy needs `proxyProtocol` for towonel, and Envoy cannot apply PROXY protocol to a QUIC listener. Setting both makes the UDP listener invalid; Envoy rejects it silently and serves its last good config forever, so a new `SecurityPolicy` lands on the TCP listener only and forward auth doesn't run over HTTP/3. ([ADR-0016](../adr/0016-no-http3-on-envoy-gateways.md))
- **Tailscale state secrets are not ExternalSecrets:** `ts-ai3090-node-0` and `operator` are written by `tailscaled` and the operator themselves. ESO must never template `_current-profile`, `_profiles`, `_machinekey` or `profile-*` into either — an hourly refresh replays a stale profile, the device re-registers under a new identity, and the pod crash-loops on `invalid key`. Credentials live in separate ESO-managed secrets: `ts-ai3090-node-authkey` for the node, `tailscale-operator-secret` (OAuth) for the operator.
- **Don't set `TS_DEBUG_MTU` in the ProxyClass:** 1280 is already tailscaled's default TUN MTU, so the override changed nothing and the operator logs a warning that custom Tailscale env vars may break in future releases.
- **BGP CRDs are feature-gated:** They only install when `bgpControlPlane.enabled: true` in the Helm chart. Enabling it in an existing cluster via Flux causes a dry-run deadlock (the Kustomization validates `networks.yaml` before the HelmRelease upgrades). Fix: `kubectl apply -n kube-system -f kubernetes/apps/kube-system/cilium/app/helmrelease.yaml --server-side --field-manager=kustomize-controller` to break the cycle.

## Gateways

| Gateway          | Namespace | Use case             |
| ---------------- | --------- | -------------------- |
| `envoy-internal` | `network` | LAN-only apps        |
| `envoy-external` | `network` | Internet-facing apps |

Domain variable: `${SECRET_DOMAIN}` (from `cluster-secrets` Secret).

## HTTPRoute Pattern

Routes are **inline in the HelmRelease** `values.route` block — no separate HTTPRoute manifest. Exception: routes needing path-level auth (e.g., `prometheus-remote-write`) use a standalone `httproute-*.yaml` file. ([ADR-0002](../adr/0002-flux-repository-conventions.md))

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

`pocket-id` (`security` ns, at `id.${SECRET_DOMAIN}`) is the cluster IdP. `tinyauth` (`security` ns, at `auth.${SECRET_DOMAIN}`) is the forward-auth proxy in front of apps that have no OIDC support of their own. Both live in `kubernetes/apps/security/`. ([ADR-0014](../adr/0014-pocket-id-tinyauth-over-authentik.md))

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

Requires `dependsOn: {name: pocket-id, namespace: security}` in `ks.yaml`. Available groups: `id-admin`, `id-home`, `id-family`, `id-friends`, `id-users`. See `secrets.md` for the companion `PushSecret` that backs the generated credentials up to aKeyless.

### Forward auth (apps with no OIDC support)

The `auth` app component, one for both gateways — there is no internal/external split. It sends ext-auth to `tinyauth.security:3000` via a `SecurityPolicy`, and it changes how the app is monitored.

Full stanza, substitution vars and the required Gatus annotation swap: `components.md` → `auth`.

## Gatus Health Monitoring

The `gatus-sidecar` runs with `--auto-httproute --enable-httproute --enable-service`. **No annotation or action is needed** — it auto-discovers every HTTPRoute automatically.

**Exception — apps using the `auth` component:** the tinyauth redirect means the route never returns 200, so monitoring has to move from the route to the service. The annotations are in `components.md` → `auth`.

## DNS

- `external-dns` manages Cloudflare DNS records automatically from HTTPRoute annotations.
- `external-dns` does **not** create wildcard records. `*.s3.${SECRET_DOMAIN}` (rustfs virtual-hosted-style S3 addressing) is a manual Cloudflare record, pointing at the same target as `s3.${SECRET_DOMAIN}`.
- Internal DNS: CoreDNS + `unifi-dns` for `.internal` hostnames.
