# Cloudflared Integration with Gateway API

This document details the strategies for integrating Cloudflared with Envoy Gateway during the migration from NGINX Ingress to Gateway API.

## Current Cloudflared Setup

Cloudflared currently creates a secure tunnel from Cloudflare's edge to your cluster's NGINX Ingress controller:

```
Internet → Cloudflare Edge → Cloudflared Tunnel → NGINX Ingress (192.168.5.240) → Services
```

DNS Flow:
- Application hostname (e.g., `ha.domain.com`) → CNAME → `external.domain.com`
- `external.domain.com` → CNAME → `<tunnel-id>.cfargotunnel.com`
- Cloudflared tunnel routes to 192.168.5.240 (NGINX Ingress)

## Migration Strategies

### Strategy A: DNS-Based Gradual Migration (Recommended)

**Overview**: Use different DNS targets for Ingress vs Gateway API during transition.

**Architecture**:
```
Internet → Cloudflare Edge → Cloudflared Tunnel → Both controllers

Tunnel routes to:
- 192.168.5.240 (NGINX Ingress) - legacy apps
- 192.168.5.241 (Envoy Gateway) - migrated apps

DNS determines which backend receives traffic
```

**Implementation Steps**:

1. **Keep existing cloudflared configuration unchanged**
   - Cloudflared continues tunneling to NGINX
   - No changes to `kubernetes/apps/network/external/cloudflared/configs/config.yaml`

2. **Create new DNS target for Gateway API**
   - Add annotation to external Gateway:
     ```yaml
     annotations:
       external-dns.alpha.kubernetes.io/hostname: "external-gw.${SECRET_DOMAIN}"
     ```
   - external-dns creates: `external-gw.domain.com` → `<tunnel-id>.cfargotunnel.com`

3. **Migrate applications one by one**
   - Create HTTPRoute with target annotation:
     ```yaml
     apiVersion: gateway.networking.k8s.io/v1
     kind: HTTPRoute
     metadata:
       name: app-name
       annotations:
         external-dns.alpha.kubernetes.io/hostname: "app.${SECRET_DOMAIN}"
         external-dns.alpha.kubernetes.io/target: "external-gw.${SECRET_DOMAIN}"
     spec:
       hostnames:
         - "app.${SECRET_DOMAIN}"
       # ... rest of config
     ```
   - Delete or disable corresponding Ingress
   - external-dns updates DNS: `app.domain.com` → CNAME → `external-gw.domain.com`
   - Traffic now flows through Gateway API

4. **Verify routing**
   ```bash
   # Check DNS record
   dig app.domain.com

   # Should show:
   # app.domain.com → CNAME → external-gw.domain.com
   # external-gw.domain.com → CNAME → <tunnel-id>.cfargotunnel.com
   ```

**Pros**:
- ✅ Zero downtime per application
- ✅ Easy rollback (recreate Ingress)
- ✅ Test individual apps before full migration
- ✅ Both systems operational simultaneously

**Cons**:
- ❌ Requires external-dns updates
- ❌ Two DNS targets during transition
- ❌ Slightly more complex DNS configuration

**Cloudflared Config Changes**: None required during migration

---

### Strategy B: Multi-Origin Cloudflared Tunnel

**Overview**: Configure cloudflared with multiple origins, using path-based routing.

**Architecture**:
```
Internet → Cloudflare Edge → Cloudflared Tunnel
                                  ├→ 192.168.5.240 (NGINX Ingress) - legacy apps
                                  └→ 192.168.5.241 (Envoy Gateway) - migrated apps
```

**Implementation Steps**:

1. **Update cloudflared configuration**:
   ```yaml
   # kubernetes/apps/network/external/cloudflared/configs/config.yaml
   tunnel: <tunnel-id>
   credentials-file: /etc/cloudflared/creds/credentials.json

   ingress:
     # Route specific hostnames to Gateway API
     - hostname: app1.domain.com
       service: https://192.168.5.241
       originRequest:
         originServerName: app1.domain.com

     - hostname: app2.domain.com
       service: https://192.168.5.241
       originRequest:
         originServerName: app2.domain.com

     # Default route to NGINX for all other traffic
     - service: https://192.168.5.240
   ```

2. **Migrate applications**:
   - Add hostname entry to cloudflared config for Gateway API
   - Create HTTPRoute
   - Delete Ingress
   - Cloudflared routes hostname to new backend

**Pros**:
- ✅ Explicit routing control
- ✅ Clear configuration of what goes where
- ✅ Can route based on hostname or path

**Cons**:
- ❌ Requires cloudflared config changes per app
- ❌ More manual intervention
- ❌ Config drift between DNS and cloudflared
- ❌ Cloudflared pod restart on config changes

**Cloudflared Config Changes**: Update per application migration

---

### Strategy C: Full Cutover (Not Recommended)

**Overview**: Switch entire tunnel to Gateway API in one operation.

**Architecture**:
```
Internet → Cloudflare Edge → Cloudflared Tunnel → Envoy Gateway (192.168.5.241) → Services
```

**Implementation Steps**:

1. **Migrate ALL Ingress to HTTPRoute** first
   - Must be 100% complete before cutover
   - No ability to test incrementally

2. **Update cloudflared configuration**:
   ```yaml
   tunnel: <tunnel-id>
   credentials-file: /etc/cloudflared/creds/credentials.json

   ingress:
     - service: https://192.168.5.241
   ```

3. **Apply and restart cloudflared**:
   ```bash
   kubectl rollout restart deployment cloudflared -n network
   ```

**Pros**:
- ✅ Simplest final configuration
- ✅ Complete migration

**Cons**:
- ❌ High risk - all apps affected simultaneously
- ❌ No incremental testing
- ❌ Difficult rollback
- ❌ Requires complete migration first

**Cloudflared Config Changes**: One-time full replacement

---

### Strategy D: Dual Tunnel Approach

**Overview**: Run two cloudflared tunnels simultaneously during migration.

**Architecture**:
```
Internet → Cloudflare Edge
              ├→ Tunnel A → NGINX Ingress (192.168.5.240) - legacy
              └→ Tunnel B → Envoy Gateway (192.168.5.241) - new
```

**Implementation Steps**:

1. **Create second cloudflared tunnel**:
   ```bash
   # In Cloudflare dashboard or via API
   cloudflared tunnel create envoy-gateway-tunnel
   ```

2. **Deploy second cloudflared instance**:
   ```yaml
   # kubernetes/apps/network/external/cloudflared-gateway/helmrelease.yaml
   # Similar to existing cloudflared but:
   # - Different tunnel ID
   # - Different credentials
   # - Points to 192.168.5.241
   ```

3. **Configure DNS per application**:
   - Legacy apps: `app.domain.com` → `tunnel-a.cfargotunnel.com`
   - Migrated apps: `app.domain.com` → `tunnel-b.cfargotunnel.com`

4. **Migrate incrementally**:
   - Create HTTPRoute
   - Update DNS to use tunnel-b
   - Delete Ingress

**Pros**:
- ✅ Complete isolation between old and new
- ✅ Independent scaling and configuration
- ✅ Easy rollback (DNS change)
- ✅ No shared state

**Cons**:
- ❌ Requires second tunnel creation
- ❌ More complex - two tunnels to manage
- ❌ Additional cloudflared pods/resources
- ❌ Cloudflare Zero Trust plan limits may apply

**Cloudflared Config Changes**: New deployment, existing unchanged

---

## Recommended Strategy: A (DNS-Based Gradual Migration)

Strategy A is recommended because:

1. **Minimal Changes**: No cloudflared reconfiguration needed
2. **Safe Rollback**: Simply recreate Ingress resource
3. **Incremental**: Test each app individually
4. **GitOps Friendly**: All changes in Git, no manual DNS
5. **external-dns Automation**: Automatic DNS management

## Implementation Example: Strategy A

### Step-by-Step for Single Application (hassio)

**Before Migration**:
```yaml
# kubernetes/apps/network/proxy/apps/hassio.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hassio
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "ha.${SECRET_DOMAIN}"
    external-dns.alpha.kubernetes.io/target: "external.${SECRET_DOMAIN}"
spec:
  ingressClassName: external
  rules:
    - host: "ha.${SECRET_DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hassio
                port:
                  name: http
```

DNS: `ha.domain.com` → `external.domain.com` → `<tunnel-id>.cfargotunnel.com` → NGINX (192.168.5.240)

**During Migration**:

1. Create HTTPRoute:
```yaml
# kubernetes/apps/network/proxy/apps/hassio-httproute.yaml
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
    - backendRefs:
        - name: hassio
          port: 80
```

2. Test via Gateway IP:
```bash
curl -H "Host: ha.domain.com" https://192.168.5.241 -k
```

3. When ready, rename files:
```bash
mv hassio.yaml hassio-ingress.yaml.bak
mv hassio-httproute.yaml hassio.yaml
```

**After Migration**:

DNS: `ha.domain.com` → `external-gw.domain.com` → `<tunnel-id>.cfargotunnel.com` → Gateway (192.168.5.241)

Cloudflared config: **Unchanged**

## Monitoring Cloudflared

```bash
# Check cloudflared status
kubectl get pods -n network -l app=cloudflared

# Check cloudflared logs
kubectl logs -n network -l app=cloudflared -f

# Check metrics
kubectl port-forward -n network svc/cloudflared 8080:8080
curl http://localhost:8080/metrics
```

## Troubleshooting

### Issue: Cloudflared can't connect to Gateway

**Symptoms**: 502 Bad Gateway errors

**Checks**:
```bash
# Verify Gateway LoadBalancer is reachable
curl -k https://192.168.5.241

# Check from cloudflared pod
kubectl exec -it -n network deployment/cloudflared -- wget -O- https://192.168.5.241 --no-check-certificate

# Verify Envoy proxy is running
kubectl get pods -n network -l app.kubernetes.io/name=envoy-gateway
```

**Solution**: Ensure Gateway LoadBalancer service is created and has IP assigned

### Issue: TLS handshake errors

**Symptoms**: TLS verification errors in cloudflared logs

**Solution**: Configure originServerName in cloudflared:
```yaml
ingress:
  - hostname: app.domain.com
    service: https://192.168.5.241
    originRequest:
      originServerName: app.domain.com
      noTLSVerify: false  # Set to true temporarily for testing
```

### Issue: Wrong backend receiving traffic

**Symptoms**: Application on NGINX when should be on Gateway (or vice versa)

**Checks**:
```bash
# Check DNS records
dig app.domain.com

# Check external-dns logs
kubectl logs -n network -l app.kubernetes.io/name=external-dns

# Check HTTPRoute annotations
kubectl get httproute <name> -n <namespace> -o yaml
```

**Solution**: Verify external-dns target annotation matches intended backend

## Security Considerations

1. **TLS Verification**: Cloudflared should verify TLS certificates
   - Ensure cert-manager certificate is valid
   - Configure originServerName correctly

2. **Origin Authentication**: Consider Cloudflare Access or mTLS
   - Adds authentication between Cloudflare and origin

3. **DDoS Protection**: Cloudflare provides DDoS protection at edge
   - No changes needed during migration

4. **WAF Rules**: Review Cloudflare WAF rules
   - Test with Gateway API before production cutover

## Cost Considerations

- **Single Tunnel**: No additional costs
- **Dual Tunnel** (Strategy D): Check Cloudflare Zero Trust plan limits
- **Bandwidth**: No change in bandwidth costs

## Conclusion

Strategy A (DNS-Based Gradual Migration) provides the best balance of safety, flexibility, and simplicity for migrating cloudflared from NGINX Ingress to Envoy Gateway.

Key points:
- No cloudflared configuration changes needed
- Leverage external-dns for automation
- Per-application migration and rollback
- Both systems operational during transition
