# Envoy Gateway with Gateway API

Gateway API implementation using Envoy Gateway for application routing and ingress.

## Status

✅ Migration from nginx Ingress completed November 2025

## Architecture

```
External: Internet → Cloudflare → Cloudflared → envoy-external (192.168.5.241) → Apps
Internal: LAN → k8s-gateway → envoy-internal (192.168.5.231) → Apps
```

### Components

| Component | Purpose | IP |
|-----------|---------|-----|
| **envoy-external** | External Gateway (HTTPS) | 192.168.5.241 |
| **envoy-internal** | Internal Gateway (HTTPS) | 192.168.5.231 |
| **external-dns** | DNS automation (watches HTTPRoute) | - |
| **k8s-gateway** | Internal DNS (watches HTTPRoute) | 192.168.5.199 |
| **cloudflared** | Cloudflare tunnel | - |

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
            port: *port  # Variable reference from service definition
```

**External Apps:**
```yaml
route:
  app:
    annotations:
      gatus.home-operations.com/endpoint: |-
        conditions: ["[STATUS] == 200"]
    hostnames: ["app.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-external
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *port  # Variable reference from service definition
```

## Authentication (Authentik)

For apps requiring authentication, use the appropriate `ext-auth` component:

**For internal apps (envoy-internal):**
```yaml
# In app's kustomization.yaml
components:
  - ../../../../components/ext-auth-internal
```

**For external apps (envoy-external):**
```yaml
# In app's kustomization.yaml
components:
  - ../../../../components/ext-auth-external
```

**In app's ks.yaml:**
```yaml
postBuild:
  substitute:
    APP: app-name  # Must match HelmRelease/HTTPRoute name
```

See `kubernetes/components/ext-auth-internal/` and `kubernetes/components/ext-auth-external/` for SecurityPolicy configuration.

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
- **Minio**: Dual routes (app + s3)
- **Gatus**: Self-monitoring disabled
- **Kromgo**: 404 health check status

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

**Authentik auth not working:**
```bash
kubectl get securitypolicy -A
kubectl get referencegrant -n default
# Verify ext-auth component is applied and APP variable is set
```

## Additional Documentation

- **[MIGRATION.md](./MIGRATION.md)**: Migration guide with cloudflared integration and conversion patterns
- **[ext-auth component](../../../components/ext-auth/)**: Authentik SecurityPolicy configuration

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [external-dns Gateway Support](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/gateway-api.md)
