## Pangolin

VPS-hosted Pangolin instance (RackNerd) fronts all `envoy-external` traffic via a Newt WireGuard tunnel into the cluster.

### Cut-over (Option A)
- `cloudflared` ks disabled — its DNSEndpoint released `external.${SECRET_DOMAIN}` CNAME ownership in Cloudflare
- `pangolin-operator/config/dnsendpoint.yaml` now publishes `external.${SECRET_DOMAIN}` A → VPS IP via the Cloudflare `external-dns` instance (sources: `crd`, `gateway-httproute`)
- `envoy-external` Gateway infra hostname annotation is unchanged — `unifi-dns` (sources: `service`) still writes the LAN-side `external.${SECRET_DOMAIN}` → `192.168.5.241` record for split-horizon DNS
- Every HTTPRoute parented to `envoy-external` is auto-discovered as a Pangolin resource (`enableRouteDiscovery: true` + `gatewayName: envoy-external`); use `pangolin-operator/enabled: "false"` to opt out

### Per-route overrides
Annotations only needed when overriding defaults (SSO, target path, host header, custom auth, etc.). See operator README for the full annotation table.

### Revert
- Uncomment `./cloudflared/ks.yaml` and comment `./pangolin-operator/ks.yaml` in `kubernetes/apps/network/kustomization.yaml`
- Restore `dependsOn: cloudflared` on `apps/network/echo/app/helmrelease.yaml`
