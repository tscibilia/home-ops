# Gateway API Migration Guide

This guide provides step-by-step instructions for migrating from Kubernetes Ingress (NGINX) to Gateway API with Envoy Gateway.

## Overview

This migration uses a phased approach to ensure zero downtime and safe rollback capabilities:

- **Phase 1**: Install Envoy Gateway alongside existing NGINX Ingress
- **Phase 2**: Create parallel HTTPRoute resources
- **Phase 3**: Test HTTPRoutes with dedicated IPs
- **Phase 4**: Gradual cutover per-application
- **Phase 5**: Deprecate old Ingress resources

## Current Architecture

### External Traffic (192.168.5.240)
- **Ingress Controller**: NGINX (`external` IngressClass)
- **Tunnel**: Cloudflared → NGINX Ingress
- **DNS**: external-dns (watches Ingress resources)
- **TLS**: cert-manager wildcard certificate

### Internal Traffic (192.168.5.230)
- **Ingress Controller**: NGINX (`internal` IngressClass - default)
- **DNS**: k8s-gateway (CoreDNS plugin)
- **TLS**: cert-manager wildcard certificate

## Target Architecture

### External Traffic
- **Gateway**: Envoy Gateway on 192.168.5.241 (`external` GatewayClass)
- **Routes**: HTTPRoute resources
- **Tunnel**: Cloudflared → Envoy Gateway (see Cloudflared section)
- **DNS**: external-dns (watches HTTPRoute resources)
- **TLS**: cert-manager wildcard certificate

### Internal Traffic
- **Gateway**: Envoy Gateway on 192.168.5.231 (`internal` GatewayClass)
- **Routes**: HTTPRoute resources
- **DNS**: k8s-gateway (no changes needed)
- **TLS**: cert-manager wildcard certificate

## Phase 1: Install Envoy Gateway

### 1.1 Enable Envoy Gateway Installation

Uncomment the Envoy Gateway kustomization in `kubernetes/apps/network/kustomization.yaml`:

```yaml
resources:
  # ... existing resources ...
  - ./envoy-gateway/ks.yaml  # Uncomment this line
```

### 1.2 Verify Installation

After Flux reconciles, verify:

```bash
# Check Envoy Gateway controller is running
kubectl get pods -n network -l control-plane=envoy-gateway

# Check GatewayClasses are created
kubectl get gatewayclasses

# Check Gateways are ready
kubectl get gateways -n network

# Check LoadBalancer IPs are assigned
kubectl get svc -n network | grep envoy
```

Expected output:
- External Gateway should have IP 192.168.5.241
- Internal Gateway should have IP 192.168.5.231

### 1.3 Verify TLS Certificate Access

Check that the ReferenceGrant allows Gateways to access cert-manager secrets:

```bash
kubectl get referencegrant -n cert-manager
kubectl describe gateway external -n network
kubectl describe gateway internal -n network
```

## Phase 2: Create Parallel HTTPRoute Resources

### 2.1 Convert Ingress to HTTPRoute

For each Ingress resource, create a corresponding HTTPRoute. Examples are provided:

**Internal Service Example** (see `kubernetes/apps/observability/kite/app/httproute.yaml`):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kite
spec:
  parentRefs:
    - name: internal
      namespace: network
      sectionName: https
  hostnames:
    - "kite.${SECRET_DOMAIN}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: kite
          port: 80
```

**External Service Example** (see `kubernetes/apps/network/proxy/apps/hassio-httproute.yaml`):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hassio
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "ha.${SECRET_DOMAIN}"
    external-dns.alpha.kubernetes.io/target: "external-gw.${SECRET_DOMAIN}"
spec:
  parentRefs:
    - name: external
      namespace: network
      sectionName: https
  hostnames:
    - "ha.${SECRET_DOMAIN}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: hassio
          port: 80
```

### 2.2 Key Differences: Ingress vs HTTPRoute

| Aspect | Ingress | HTTPRoute |
|--------|---------|-----------|
| Class selection | `ingressClassName: external` | `parentRefs[].name: external` |
| Hostname | `spec.rules[].host` | `spec.hostnames[]` |
| Path matching | `spec.rules[].http.paths[]` | `spec.rules[].matches[].path` |
| Backend | `backend.service` | `backendRefs[]` |
| TLS | `spec.tls[]` | Configured on Gateway |
| Namespace | Same namespace only | Cross-namespace via ReferenceGrant |

### 2.3 Test Strategy

Create HTTPRoutes with test subdomains first:

```yaml
hostnames:
  - "test-app.${SECRET_DOMAIN}"
```

This allows testing via Gateway IP (192.168.5.241/231) without affecting production traffic.

## Phase 3: External-DNS and Cloudflared Integration

### 3.1 Enable Gateway API in external-dns

Update external-dns to watch Gateway API resources:

1. Backup current configuration:
   ```bash
   cp kubernetes/apps/network/external/external-dns/helmrelease.yaml \
      kubernetes/apps/network/external/external-dns/helmrelease-ingress-only.yaml.bak
   ```

2. Replace with Gateway API enabled version:
   ```bash
   mv kubernetes/apps/network/external/external-dns/helmrelease-gateway-api.yaml \
      kubernetes/apps/network/external/external-dns/helmrelease.yaml
   ```

3. Wait for external-dns to reconcile:
   ```bash
   kubectl logs -n network -l app.kubernetes.io/name=external-dns -f
   ```

### 3.2 Cloudflared Integration

Cloudflared currently points to the NGINX Ingress LoadBalancer. Two strategies for migration:

#### Strategy A: DNS-based routing (Recommended)
1. Keep cloudflared pointing to NGINX
2. Use different subdomains for Gateway API testing (e.g., `test-*.domain.com`)
3. external-dns will create DNS records pointing to `external-gw.domain.com`
4. Gradually move applications by:
   - Creating HTTPRoute with production hostname
   - Deleting/disabling corresponding Ingress
   - external-dns automatically updates DNS

#### Strategy B: Cloudflared service switching
1. Update cloudflared config to point to new Gateway LoadBalancer:
   ```yaml
   # In kubernetes/apps/network/external/cloudflared/configs/config.yaml
   ingress:
     - service: https://192.168.5.241  # New Gateway IP
   ```
2. All traffic immediately switches to Gateway API
3. Higher risk - requires all Ingress → HTTPRoute migration first

**Recommendation**: Use Strategy A for gradual, safe migration.

See [CLOUDFLARED-INTEGRATION.md](./CLOUDFLARED-INTEGRATION.md) for detailed strategies.

## Phase 4: Gradual Application Cutover

### 4.1 Per-Application Migration Checklist

For each application:

- [ ] Create HTTPRoute resource
- [ ] Verify HTTPRoute is bound to Gateway
  ```bash
  kubectl describe httproute <name> -n <namespace>
  ```
- [ ] Test via direct Gateway IP or test subdomain
- [ ] Verify external-dns created DNS records (if external)
- [ ] Switch DNS or delete Ingress (depending on strategy)
- [ ] Monitor application health
- [ ] Verify Gatus monitoring still works

### 4.2 Testing Tools

```bash
# Check HTTPRoute status
kubectl get httproutes -A

# Check Gateway status and routes
kubectl describe gateway external -n network
kubectl describe gateway internal -n network

# Test direct IP access (bypass DNS)
curl -H "Host: app.domain.com" https://192.168.5.241 -k

# Check external-dns logs
kubectl logs -n network -l app.kubernetes.io/name=external-dns -f

# Check Envoy Gateway logs
kubectl logs -n network -l control-plane=envoy-gateway -f
```

### 4.3 Rollback Procedure

If issues occur:

1. **Quick rollback**: Re-enable Ingress resource
   ```bash
   kubectl apply -f <ingress-backup.yaml>
   ```

2. **DNS rollback**: external-dns will automatically revert

3. **Full rollback**: Comment out envoy-gateway in kustomization
   ```yaml
   # - ./envoy-gateway/ks.yaml
   ```

## Phase 5: Deprecate Ingress Resources

Once all applications are migrated and stable:

### 5.1 Remove Ingress Resources
```bash
# Archive Ingress files
mkdir -p kubernetes/apps/network/archived/ingress
mv kubernetes/apps/network/external/ingress-nginx kubernetes/apps/network/archived/ingress/
mv kubernetes/apps/network/internal/ingress-nginx kubernetes/apps/network/archived/ingress/
```

### 5.2 Update Kustomizations
Remove ingress-nginx references from:
- `kubernetes/apps/network/external/ks.yaml`
- `kubernetes/apps/network/internal/ks.yaml`

### 5.3 Update external-dns
Remove Ingress-specific configuration from external-dns:
```yaml
sources:
  - gateway-httproute
  - gateway-grpcroute
  - crd
# Remove: - ingress
```

## Monitoring and Troubleshooting

### Key Metrics to Watch
- Gateway status and listener status
- HTTPRoute binding status
- Envoy proxy pod status
- TLS certificate status
- DNS record creation/updates
- Application response times

### Common Issues

**Issue**: Gateway not getting LoadBalancer IP
- **Solution**: Check Cilium LBIPAM configuration, verify IP pool availability
  ```bash
  kubectl get ciliumpodippools
  kubectl get ciliumloadbalancerippools
  ```

**Issue**: HTTPRoute not binding to Gateway
- **Solution**: Check namespace, parentRefs, and Gateway listener configuration
  ```bash
  kubectl describe httproute <name> -n <namespace>
  ```

**Issue**: TLS certificate not working
- **Solution**: Verify ReferenceGrant allows cross-namespace secret access
  ```bash
  kubectl get referencegrant -n cert-manager
  kubectl describe gateway <name> -n network
  ```

**Issue**: external-dns not creating records
- **Solution**: Check external-dns logs, verify Gateway API sources are enabled
  ```bash
  kubectl logs -n network -l app.kubernetes.io/name=external-dns
  ```

## Benefits of Gateway API

- **Better separation of concerns**: Infrastructure vs application routing
- **Enhanced traffic management**: Timeouts, retries, rate limiting
- **Multiple protocols**: HTTP, HTTPS, gRPC, TCP, UDP, TLS
- **Cross-namespace routing**: With ReferenceGrant
- **Vendor neutral**: Not tied to specific implementation
- **Kubernetes SIG standard**: Future-proof

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [external-dns Gateway API Support](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/gateway-api.md)
- [Cilium Load Balancer IPAM](https://docs.cilium.io/en/stable/network/lb-ipam/)

## Support

For issues specific to this migration:
1. Check Gateway and HTTPRoute status
2. Review Envoy Gateway logs
3. Verify network connectivity to new LoadBalancer IPs
4. Test with curl/direct IP access first before DNS

For general Gateway API questions, refer to upstream documentation.
