# Envoy Gateway with Gateway API

Gateway API implementation using Envoy Gateway for application routing and ingress.

## Status

✅ Migration from nginx Ingress completed November 2025

## Architecture

```
External: Internet → Cloudflare → Cloudflared → envoy-external (192.168.42.41) → Apps
Internal: LAN → k8s-gateway → envoy-internal (192.168.42.31) → Apps
```

### Components

| Component          | Purpose                                     | IP            |
| ------------------ | ------------------------------------------- | ------------- |
| **envoy-external** | External Gateway (HTTPS)                    | 192.168.42.41 |
| **envoy-internal** | Internal Gateway (HTTPS)                    | 192.168.42.31 |
| **external-dns**   | DNS automation (watches HTTPRoute)          | -             |
| **unifi-dns**      | Internal DNS automation (watches HTTPRoute) | -             |
| **cloudflared**    | Cloudflare tunnel                           | -             |

## HTTPRoute Pattern

All apps use inline `route:` blocks in HelmRelease:

**Internal Apps:**

```yaml
route:
    app:
        hostnames: ["app.${SECRET_DOMAIN}"]
        parentRefs:
            - name: envoy-internal
              namespace: network
        rules:
            - backendRefs:
                  - identifier: app
                    port: *port # Variable reference from service definition
```

**External Apps:**

```yaml
route:
    app:
        hostnames: ["app.${SECRET_DOMAIN}"]
        parentRefs:
            - name: envoy-external
              namespace: network
        rules:
            - backendRefs:
                  - identifier: app
                    port: *port # Variable reference from service definition
```

## Authentication (Tinyauth)

For apps requiring forward auth, add the `auth` component. There is a single
component for both gateways — the SecurityPolicy targets the app's HTTPRoute,
not the gateway, so internal and external apps use the same one:

```yaml
# In app's ks.yaml
components:
    - ../../../../components/auth
```

**In app's ks.yaml:**

```yaml
postBuild:
    substitute:
        APP: app-name # Must match HelmRelease/HTTPRoute name
```

See `kubernetes/components/auth/` for SecurityPolicy configuration. Override
`EXT_AUTH_TARGET`, `EXT_AUTH_KIND` or `EXT_AUTH_GROUP` if the policy needs to
target something other than an HTTPRoute named `${APP}`.

## Monitoring

```bash
# Gateway status
kubectl get gateways -n network

# HTTPRoute status
kubectl get httproutes -A

# Envoy controller logs
kubectl logs -n network -l control-plane=envoy-gateway -f

# Envoy proxy logs
kubectl logs -n network -l gateway.envoyproxy.io/owning-gateway-name=envoy-external -f
```

## Special Cases

- **Plex**: Custom Range header removal for subtitle streaming (401 health check)
- **Gatus**: Self-monitoring disabled

## Troubleshooting

**Gateway not ready:**

```bash
kubectl describe gateway envoy-external -n network
kubectl get svc -n network | grep envoy
```

**HTTPRoute not binding:**

```bash
kubectl describe httproute <name> -n <namespace>
# Check: parentRefs.name, parentRefs.namespace, sectionName
```

**Tinyauth forward auth not working:**

```bash
kubectl get securitypolicy -A
kubectl get referencegrant -n security
# Verify auth component is applied and APP variable is set
```

## Additional Documentation

- **[MIGRATION.md](./MIGRATION.md)**: Migration guide with cloudflared integration and conversion patterns
- **[auth component](../../../components/auth/)**: Tinyauth SecurityPolicy configuration

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [external-dns Gateway Support](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/gateway-api.md)
