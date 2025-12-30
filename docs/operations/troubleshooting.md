# Troubleshooting Guide

## When Do You Actually Need This?

Kubernetes is self-healing. Most of the time, things just work. If a pod crashes, it restarts. If a node goes down, pods move to healthy nodes. If you're updating an app and it fails, Flux rolls back to the previous working version automatically.

You only need to troubleshoot when:

1. **Pushover alert on your phone hasn't cleared**
   The cluster sends alerts for issues that persist beyond self-healing timeouts.

2. **AlertManager shows active firing alerts**
   Check [https://am.t0m.co](https://am.t0m.co) (when connected to internal network) for currently firing alerts and their details.

3. **Status page shows degraded services**
   Check [https://status.t0m.co](https://status.t0m.co) for a quick overview of what's working and what's not.

If none of these are showing problems, the cluster is probably fine. Temporary errors during deployments are normal and resolve automatically.

## Quick Health Check

Before digging into specific issues:

```bash
# Check overall cluster health
kubectl get nodes  # All should be Ready

# Check for pods in bad states
kubectl get pods -A | grep -v "Running\|Completed"

# Check Flux status
flux get all -A | grep -v "True"
```

If everything looks good, you're probably overthinking it. Kubernetes handles transient issues on its own.

## Common Scenarios

### Updating an App and It Fails

**What happens**: You push a change, the app fails to deploy, Flux rolls back automatically.

**Symptoms**: HelmRelease shows `Failed` status, but pods are still running the old version.

**Why it's usually fine**: Flux's fail-safe behavior means failed deployments don't take down working apps.

**When to intervene**:

- AlertManager fires an alert
- The app shows `Failed` for more than 10 minutes
- You need to force the update despite errors

**Fix**:

```bash
# Check what went wrong
kubectl describe helmrelease <name> -n <namespace>

# If it's a configuration error, fix it in Git and push

# If you need to force a clean slate
kubectl delete helmrelease <name> -n <namespace>
just kube ks-reconcile <namespace> <app-name>
```

### Adding a New App and It Won't Deploy

**Symptoms**: New app's Kustomization stays in `Progressing` or `Failed` state.

**Common causes**:

- Missing dependency (database, secret, CRD)
- Typo in configuration
- Wrong image reference

**Fix**:

```bash
# Check dependency chain
kubectl describe kustomization <app-name> -n flux-system

# Look for dependency failures
kubectl get kustomization -A | grep False

# Fix dependencies first, then retry
just kube ks-reconcile <namespace> <app-name>
```

### Network Changes Breaking Things

**Symptoms**: Everything was working, you changed networking config, now apps are unreachable.

**What to check**:

```bash
# Did you break Cilium?
kubectl get pods -n kube-system | grep cilium

# Are LoadBalancer IPs allocated?
kubectl get svc -A | grep LoadBalancer

# Is Cloudflared tunnel up?
kubectl get pods -n network | grep cloudflared

# Are HTTPRoutes configured?
kubectl get httproute -A
```

**Nuclear option** (restart networking stack in order):

```bash
just kube restart-network
```

This restarts CoreDNS → Cilium → Cloudflared → external-dns → Envoy in dependency order. Only use this if you're confident networking is the problem.

## Alert-Driven Troubleshooting

### Using AlertManager

AlertManager at [https://am.t0m.co](https://am.t0m.co) shows active alerts with:

- **Alert name**: What's failing
- **Labels**: Which namespace/app
- **Annotations**: Description and suggested actions
- **Firing duration**: How long it's been broken

Alerts are configured to fire only after issues persist beyond self-healing thresholds. If an alert is firing, intervention is likely needed.

??? tip "Common Alerts and What They Mean"
    - **PodCrashLooping**: Pod restarting repeatedly (check logs: `kubectl logs <pod> -n <namespace> --previous`)
    - **PVCFull**: PersistentVolumeClaim out of space (expand PVC or clean up data)
    - **NodeNotReady**: Node unhealthy (check node logs: `talosctl -n <node-ip> logs kubelet`)
    - **HelmReleaseFailed**: Deployment failed (check HelmRelease: `kubectl describe helmrelease <name> -n <namespace>`)
    - **KustomizationFailed**: Flux can't apply manifests (check Kustomization: `kubectl describe kustomization <name> -n flux-system`)

### Using the Status Page

The status page at [https://status.t0m.co](https://status.t0m.co) provides a high-level view of service health. Powered by Gatus, it monitors:

- HTTP endpoint availability
- Response time
- Certificate validity
- DNS resolution

If a service shows as down on the status page, start troubleshooting there.

## Specific Problem Scenarios

### Stuck HelmRelease

**When this happens**: After an app update, HelmRelease shows `Progressing` forever or `Failed` with retries exhausted.

**Check**:

```bash
kubectl describe helmrelease <name> -n <namespace>
helm history <name> -n <namespace>
```

**Fix**:

```bash
# Delete the HelmRelease (Flux recreates it)
kubectl delete helmrelease <name> -n <namespace>

# Force reconcile
just kube ks-reconcile <namespace> <app-name>
```

??? warning "If That Doesn't Work"
    Sometimes Helm gets truly stuck:

    ```bash
    # Manually delete Helm secret
    kubectl delete secret -n <namespace> sh.helm.release.v1.<name>.v<version>

    # Delete deployment
    kubectl delete deployment <name> -n <namespace>

    # Reconcile again
    just kube ks-reconcile <namespace> <app-name>
    ```

### ExternalSecret Won't Sync

**Symptoms**: `SecretSyncedError` in ExternalSecret status, app can't start because secret is missing.

**Check**:

```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl get secretstore -A
```

**Fix**:

```bash
# Force resync
just kube sync-es <namespace> <secret-name>

# If that doesn't work, restart the operator
kubectl rollout restart deployment/external-secrets -n external-secrets
```

### Database Connection Failures

**Symptoms**: App logs show "can't connect to database" errors.

**Check**:

```bash
# Is the database running?
kubectl get pods -n database

# Is the secret available?
kubectl get secret -n <app-namespace> | grep pguser

# Can DNS resolve it?
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never \
  -- nslookup postgresql.database.svc.cluster.local
```

**Fix**:

```bash
# Check CNPG cluster health
kubectl get cluster -n database
kubectl describe cluster pgsql-cluster -n database

# Restart the app (forces secret refresh)
kubectl rollout restart deployment/<app> -n <namespace>
```

### PVC Out of Space

**Symptoms**: App logs show "no space left on device", alert fires for PVCFull.

**Check**:

```bash
kubectl get pvc <claim> -n <namespace>
kubectl exec -it <pod> -n <namespace> -- df -h
```

**Fix**:

```bash
# Option 1: Expand PVC (edit in Git, push, Flux expands it)
# Edit Helm values or PVC manifest to increase storage size

# Option 2: Clean up old data
just kube browse-pvc <namespace> <claim>
# Then delete old files inside the debug pod
```

### Pod CrashLoopBackOff

**Symptoms**: Pod repeatedly crashes, Pushover alert fires.

**Check**:

```bash
kubectl logs <pod> -n <namespace> --previous
kubectl describe pod <pod> -n <namespace>
```

**Common causes**:

- Application error (fix code/config)
- Missing environment variable (check ExternalSecret)
- OOMKilled (increase memory limits)
- Liveness probe too aggressive (increase `initialDelaySeconds`)

**Fix based on cause**: Edit configuration in Git, push, Flux applies it.

## Node Issues

### Node NotReady

**Symptoms**: `kubectl get nodes` shows NotReady, pods being evicted, AlertManager fires NodeNotReady.

**Check**:

```bash
kubectl describe node <node-name>
talosctl -n <node-ip> logs kubelet | tail -50
```

**Fix**:

```bash
# Often fixed by rebooting the node
just talos reboot-node <node-name>

# Wait for it to come back
kubectl wait --for=condition=ready node/<node-name> --timeout=10m
```

## Network Troubleshooting

### Can't Access App from Internet

**Check**:

```bash
# Is HTTPRoute created?
kubectl get httproute -n <namespace>

# Is Cloudflared running?
kubectl get pods -n network | grep cloudflared

# Is DNS resolving?
dig <app>.t0m.co
```

**Fix**:

```bash
# Restart cloudflared
kubectl rollout restart deployment/cloudflared -n network

# Force DNS sync
just kube sync-all-hr
```

### Can't Access App from LAN

**Check**:

```bash
# Does service have LoadBalancer IP?
kubectl get svc <service> -n <namespace>

# Is Cilium healthy?
kubectl get pods -n kube-system | grep cilium
```

**Fix**:

```bash
# Restart network stack
just kube restart-network
```

### VPN Network Issues (Multus)

**Symptoms**: qBittorrent or Prowlarr can't access internet or VPN isn't working

**Check**:

```bash
# Verify NetworkAttachmentDefinition exists
kubectl get network-attachment-definitions -n network

# Check pod has both interfaces
kubectl exec -it <pod-name> -n media -- ip addr show

# Verify routing
kubectl exec -it <pod-name> -n media -- ip route show

# Test VPN network connectivity
kubectl exec -it <pod-name> -n media -- ping 192.168.99.1
```

**Fix**:

```bash
# Restart pod to re-attach network
kubectl delete pod <pod-name> -n media

# If NetworkAttachmentDefinition is missing, check app's kustomization
kubectl get kustomization -n media <app-name> -o yaml
```

See the [VPN Networking Guide](../kubernetes/vpn-networking.md) for detailed troubleshooting.

## Emergency: Everything is Broken

If the entire cluster is down:

1. **Check node connectivity**: Can you ping 192.168.5.201/202/203?
2. **Check control plane**: `kubectl get pods -n kube-system`
3. **Reboot nodes one at a time**:

    ```bash
    just talos reboot-node talos-m01
    kubectl wait --for=condition=ready node/talos-m01 --timeout=10m
    # Repeat for m02, m03
    ```

4. **Last resort**: Rebuild from Git (`just bootstrap default`) and restore data from VolSync backups.

## Remember

- **Trust the self-healing**: If no alerts are firing, it's probably fine.
- **Check alerts first**: Pushover → AlertManager → Status page.
- **Flux rolls back failures**: Broken deployments don't break working apps.
- **Logs are your friend**: `kubectl logs`, `kubectl describe`, and `talosctl logs` tell the full story.

## Getting More Help

Still stuck?

1. Check Flux events: `flux events --for Kustomization/<name>`
2. Check all pod logs: `kubectl logs -n <namespace> <pod> --all-containers --previous`
3. Consult [DeepWiki](https://deepwiki.com/tscibilia/home-ops) for AI-generated insights
4. Review the [Operations Overview](overview.md) for more context
