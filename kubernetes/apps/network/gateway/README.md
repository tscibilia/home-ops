# Gateway API with Envoy Gateway

This directory contains the Gateway API configuration for migrating from NGINX Ingress to Envoy Gateway.

## Quick Start

### To Enable Gateway API (Phase 1)

1. Uncomment in `../kustomization.yaml`:
   ```yaml
   resources:
     - ./envoy-gateway/ks.yaml  # Uncomment this
   ```

2. Wait for Flux to reconcile:
   ```bash
   flux reconcile kustomization network --with-source
   ```

3. Verify installation:
   ```bash
   kubectl get gateways -n network
   kubectl get svc -n network | grep envoy
   ```

   Expected:
   - External Gateway: 192.168.5.241
   - Internal Gateway: 192.168.5.231

## Architecture

### Components

- **Envoy Gateway**: Gateway API controller
- **GatewayClasses**: `external` and `internal`
- **Gateways**: External (241) and Internal (231) with TLS termination
- **HTTPRoutes**: Application routing rules (replaces Ingress)

### Files

```
gateway/
├── README.md                      # This file
├── MIGRATION-GUIDE.md             # Detailed migration steps
├── CLOUDFLARED-INTEGRATION.md     # Cloudflared strategies
├── gatewayclass.yaml              # GatewayClass definitions
├── gateway-external.yaml          # External Gateway (192.168.5.241)
├── gateway-internal.yaml          # Internal Gateway (192.168.5.231)
├── rbac.yaml                      # ReferenceGrant for cert-manager
└── kustomization.yaml             # Kustomize config

../envoy-gateway/
└── app/
    ├── helmrelease.yaml           # Envoy Gateway Helm chart
    ├── ocirepository.yaml         # Chart source
    └── kustomization.yaml
```

## IP Allocation

| Service | IP | Purpose |
|---------|-----|---------|
| NGINX External (current) | 192.168.5.240 | External traffic via cloudflared |
| NGINX Internal (current) | 192.168.5.230 | Internal traffic via k8s-gateway |
| **Gateway External (new)** | **192.168.5.241** | **External traffic via cloudflared** |
| **Gateway Internal (new)** | **192.168.5.231** | **Internal traffic via k8s-gateway** |

Parallel IPs allow zero-downtime migration.

## Example: Ingress → HTTPRoute Conversion

### Before (Ingress)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "myapp.domain.com"
spec:
  ingressClassName: external
  rules:
    - host: "myapp.domain.com"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

### After (HTTPRoute)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "myapp.domain.com"
    external-dns.alpha.kubernetes.io/target: "external-gw.domain.com"
spec:
  parentRefs:
    - name: external
      namespace: network
      sectionName: https
  hostnames:
    - "myapp.domain.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: myapp
          port: 80
```

### Key Changes
- `ingressClassName` → `parentRefs[].name`
- `spec.rules[].host` → `spec.hostnames[]`
- `backend.service` → `backendRefs[]`
- Add `target` annotation for external-dns

## Migration Phases

1. **Phase 1: Install** (You are here)
   - Deploy Envoy Gateway
   - Create GatewayClasses and Gateways
   - Verify LoadBalancer IPs

2. **Phase 2: Parallel Routes**
   - Create HTTPRoutes alongside Ingress
   - Test with test subdomains

3. **Phase 3: Enable external-dns**
   - Update external-dns to watch HTTPRoutes
   - See: `../external/external-dns/helmrelease-gateway-api.yaml`

4. **Phase 4: Migrate Applications**
   - One app at a time
   - Delete Ingress, keep HTTPRoute
   - Monitor and verify

5. **Phase 5: Cleanup**
   - Remove NGINX Ingress controllers
   - Archive old configurations

## Testing

### Test HTTPRoute without DNS
```bash
# Direct IP test
curl -H "Host: myapp.domain.com" https://192.168.5.241 -k

# Check route status
kubectl describe httproute myapp -n namespace

# Check Gateway listeners
kubectl describe gateway external -n network
```

### Verify external-dns
```bash
# Check DNS records created
kubectl logs -n network -l app.kubernetes.io/name=external-dns -f

# Verify in Cloudflare dashboard
# Should see: myapp.domain.com → CNAME → external-gw.domain.com
```

## Rollback

If issues occur:

1. **Quick**: Re-enable Ingress resource
2. **Full**: Comment out `./envoy-gateway/ks.yaml` in kustomization

## Monitoring

```bash
# Gateway status
kubectl get gateways -n network

# HTTPRoute status
kubectl get httproutes -A

# Envoy Gateway controller logs
kubectl logs -n network -l control-plane=envoy-gateway -f

# Envoy proxy logs (created per-Gateway)
kubectl logs -n network -l gateway.envoyproxy.io/owning-gateway-name=external -f
```

## Documentation

- **[MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md)**: Complete migration walkthrough
- **[CLOUDFLARED-INTEGRATION.md](./CLOUDFLARED-INTEGRATION.md)**: Cloudflared strategies

## Differences from Reference Implementation

This implementation differs from onedr0p/home-ops:

1. **Dual Ingress Controllers**: We have both external and internal
2. **Cilium without Envoy**: Our Cilium doesn't use built-in Envoy
3. **Cloudflared**: External traffic tunnels through Cloudflare
4. **Parallel Operation**: Designed to run alongside NGINX during migration

## Benefits

- ✅ **Vendor Neutral**: Kubernetes SIG standard
- ✅ **Better Routing**: Advanced traffic management
- ✅ **Cross-Namespace**: Route across namespaces safely
- ✅ **Multiple Protocols**: HTTP, gRPC, TCP, UDP, TLS
- ✅ **Future Proof**: Industry direction for ingress

## Troubleshooting

### Gateway not getting IP
```bash
kubectl get svc -n network | grep envoy
kubectl describe gateway external -n network
```
Check: Cilium LBIPAM pool has available IPs

### HTTPRoute not binding
```bash
kubectl describe httproute <name> -n <namespace>
```
Check: parentRefs namespace, name, and sectionName

### TLS errors
```bash
kubectl get referencegrant -n cert-manager
kubectl describe gateway external -n network
```
Check: ReferenceGrant allows access to cert-manager secrets

## Next Steps

1. Read [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md)
2. Verify Gateway installation
3. Test with a non-critical application
4. Plan external-dns update
5. Migrate applications gradually

## Support

- Gateway API: https://gateway-api.sigs.k8s.io/
- Envoy Gateway: https://gateway.envoyproxy.io/
- Cilium Load Balancing: https://docs.cilium.io/en/stable/network/lb-ipam/
