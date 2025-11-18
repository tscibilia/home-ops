# Envoy Gateway Migration Guide

Migration reference from nginx Ingress to Envoy Gateway with Gateway API.

## Status

✅ Migration completed November 2025

## Architecture Comparison

### Before (nginx Ingress)
```
External: Internet → Cloudflare → Cloudflared → nginx-external (192.168.5.240) → Apps
Internal: LAN → k8s-gateway → nginx-internal (192.168.5.230) → Apps
```

### After (Envoy Gateway)
```
External: Internet → Cloudflare → Cloudflared → envoy-external (192.168.5.241) → Apps
Internal: LAN → k8s-gateway → envoy-internal (192.168.5.231) → Apps
```

**Key Changes:**
- Gateway API HTTPRoute replaces Ingress resources
- external-dns watches `gateway-httproute` source
- k8s-gateway watches HTTPRoute resources
- TLS certificates managed in `network` namespace
- SecurityPolicy enables Authentik forward auth

---

## Installation

Envoy Gateway installed with dual Gateways (external/internal) using Cilium IPAM for LoadBalancer IPs.

**Verification:**
```bash
kubectl get gateways -n network
# envoy-external: 192.168.5.241
# envoy-internal: 192.168.5.231
```

---

## Application Migration

Converting bjw-s app-template applications from `ingress:` blocks to `route:` blocks.

### Conversion Pattern

**Before (Ingress):**
```yaml
ingress:
  app:
    className: external
    annotations:
      external-dns.alpha.kubernetes.io/target: "external.${SECRET_DOMAIN}"
      gatus.home-operations.com/endpoint: |-
        conditions: ["[STATUS] == 200"]
    hosts:
      - host: "app.${SECRET_DOMAIN}"
        paths:
          - path: /
            service:
              identifier: app
              port: http
```

**After (HTTPRoute):**
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
            port: *port  # Use variable reference from service definition
```

**Key Changes:**
- `ingress:` → `route:`
- `className` → `parentRefs[].name` (envoy-external or envoy-internal)
- `hosts[].host` → `hostnames[]`
- `paths[]` → `rules[].backendRefs[]`
- Removed `external-dns.alpha.kubernetes.io/target` annotation (not needed)
- Added `rules:` section with `backendRefs` (required for Gateway API)
- Gatus annotations remain on HTTPRoute (for per-route monitoring config)
- Gateway-level annotations (timeouts, CORS, etc.) applied at Gateway resource level

**Gatus Monitoring with Authentik:**

For internal apps behind Authentik forward auth, gatus HTTPRoute monitoring fails due to 302 redirects. Workaround:

```yaml
# Disable HTTPRoute monitoring, enable Service monitoring
service:
  app:
    annotations:
      gatus.home-operations.com/enabled: "true"
route:
  app:
    annotations:
      gatus.home-operations.com/enabled: "false"
    hostnames: ["app.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-internal
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *port
```

This monitors the backend ClusterIP service directly, bypassing Gateway and authentication layers.

### Special Cases

**Plex (Custom Rules):**
```yaml
route:
  app:
    annotations:
      gatus.home-operations.com/endpoint: |-
        conditions: ["[STATUS] == 401"]  # Plex returns 401 when not authenticated
    hostnames: ["{{ .Release.Name }}.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-external
        namespace: network
    rules:
      - # Remove Range header for subtitle streaming
        backendRefs:
          - identifier: app
            port: 32400
        filters:
          - type: RequestHeaderModifier
            requestHeaderModifier:
              remove:
                - Range
        matches:
          - path:
              type: PathPrefix
              value: /library/streams
      - backendRefs:
          - identifier: app
            port: 32400
```

**Minio (Dual Routes):**
```yaml
route:
  app:
    # Main app route
    hostnames: ["minio.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-external
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *http  # Variable reference to console port
  s3:
    # S3 API route
    annotations:
      gatus.home-operations.com/enabled: "false"
    hostnames: ["s3.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-external
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *port  # Variable reference to S3 API port
```

**Gatus (Disabled Monitoring):**
```yaml
route:
  app:
    annotations:
      gatus.home-operations.com/enabled: "false"  # Disable self-monitoring
    hostnames: ["${GATUS_SUBDOMAIN}.${SECRET_DOMAIN}"]
    parentRefs:
      - name: envoy-external
        namespace: network
    rules:
      - backendRefs:
          - identifier: app
            port: *port  # Variable reference
```

---

## DNS Configuration

### external-dns

Updated to watch HTTPRoute resources:

```yaml
sources:
  - crd
  - gateway-httproute
  - gateway-grpcroute
```

DNS records are automatically created for HTTPRoutes. No manual DNS management needed.

### k8s-gateway

Configured to watch HTTPRoute resources:

```yaml
watchedResources:
  - HTTPRoute
  - Service
```

Internal DNS resolution works automatically for all HTTPRoutes.

---

## Cloudflared Integration

Cloudflared continues tunneling to the same hostname pattern with no configuration changes required.

### Current Setup

```yaml
# kubernetes/apps/network/cloudflared/app/helmrelease.yaml
configMaps:
  config:
    data:
      config.yaml: |-
        ingress:
          - hostname: "*.${SECRET_DOMAIN}"
            originRequest:
              http2Origin: true
              originServerName: "external.${SECRET_DOMAIN}"
            service: https://envoy-external.network.svc.cluster.local:443
          - service: http_status:404
```

**Traffic Flow:**
1. Client requests `app.${SECRET_DOMAIN}`
2. DNS: `app.domain.com` → CNAME → `${TUNNEL_ID}.cfargotunnel.com`
3. Cloudflared tunnel → `envoy-external.network.svc.cluster.local:443`
4. Envoy Gateway routes via HTTPRoute to backend service

**Note:** Alternative strategies like direct IP routing or DNS-based gradual migration were considered but not used. ClusterIP service routing provides better debuggability and service discovery.

---

## Authentik Integration (ext-auth Component)

The reusable `ext-auth` component provides forward authentication via SecurityPolicy.

### Component Structure

```
kubernetes/components/ext-auth/
├── kustomization.yaml
└── securitypolicy.yaml
```

**securitypolicy.yaml:**
```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: ${APP}  # Substituted by Flux to match HelmRelease/HTTPRoute name
spec:
  extAuth:
    failOpen: false
    headersToExtAuth:
      - accept
      - cookie
      - authorization
      - x-forwarded-proto
      - x-forwarded-host
      - x-forwarded-uri
    http:
      backendRefs:
        - name: ak-outpost-authentik-embedded-outpost
          namespace: default
          port: 9000
      path: /outpost.goauthentik.io/auth/envoy
      headersToBackend:
        - set-cookie
        - x-authentik-*  # Wildcard pattern for all Authentik headers
        - authorization
  targetRefs:
    - group: ${EXT_AUTH_GROUP:-gateway.networking.k8s.io}
      kind: ${EXT_AUTH_KIND:-HTTPRoute}
      name: ${EXT_AUTH_TARGET:-${APP}}  # Defaults to ${APP} if not specified
```

### ReferenceGrant

Allows SecurityPolicy from other namespaces to reference the Authentik service:

```yaml
# kubernetes/apps/default/authentik/app/referencegrant.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: ref-authentik-svc
  namespace: default
spec:
  from:
    - &policy
      group: gateway.envoyproxy.io
      kind: SecurityPolicy
      namespace: database
    - <<: *policy
      namespace: default
    - <<: *policy
      namespace: flux-system
    - <<: *policy
      namespace: media
    - <<: *policy
      namespace: network
    - <<: *policy
      namespace: observability
  to:
    - group: ""
      kind: Service
      name: ak-outpost-authentik-embedded-outpost
```

### Usage Example

**App's kustomization.yaml:**
```yaml
components:
  - ../../../../components/ext-auth
```

**App's ks.yaml:**
```yaml
postBuild:
  substitute:
    APP: victoria-metrics  # Must match HelmRelease/HTTPRoute name
```

This creates a SecurityPolicy in the app's namespace targeting its HTTPRoute, using Authentik's embedded outpost for authentication.

---

## Monitoring and Troubleshooting

### Check Gateway Status
```bash
kubectl get gateways -n network
kubectl describe gateway envoy-external -n network
kubectl describe gateway envoy-internal -n network
```

### Check HTTPRoute Status
```bash
kubectl get httproutes -A
kubectl describe httproute <name> -n <namespace>
```

### Check Envoy Logs
```bash
# Controller logs
kubectl logs -n network -l control-plane=envoy-gateway -f

# Proxy logs (per-Gateway)
kubectl logs -n network -l gateway.envoyproxy.io/owning-gateway-name=envoy-external -f
kubectl logs -n network -l gateway.envoyproxy.io/owning-gateway-name=envoy-internal -f
```

### Check DNS
```bash
# external-dns logs
kubectl logs -n network -l app.kubernetes.io/name=external-dns -f

# k8s-gateway logs
kubectl logs -n network -l app.kubernetes.io/name=k8s-gateway -f

# Test DNS resolution
dig app.${SECRET_DOMAIN}
```

### Common Issues

**HTTPRoute not binding to Gateway:**
- Check `parentRefs.name` matches Gateway name
- Check `parentRefs.namespace` is `network`
- Check `sectionName` matches Gateway listener (usually `https`)

**TLS errors:**
- Verify certificate exists: `kubectl get certificate -n network`
- Check Gateway references cert: `kubectl describe gateway envoy-external -n network`

**Authentik auth not working:**
- Verify SecurityPolicy exists: `kubectl get securitypolicy -n <namespace>`
- Check ReferenceGrant: `kubectl get referencegrant -n default`
- Verify APP variable is set in Flux Kustomization

---

## References

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [external-dns Gateway Support](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/gateway-api.md)
- [Authentik Envoy Integration](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
