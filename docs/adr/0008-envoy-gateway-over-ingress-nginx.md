# Envoy Gateway over ingress-nginx

**Status:** accepted
**Date:** 2025-10-21 (nginx removed 2025-11-10)
**Supersedes:** ADR-0001 (ingress-nginx, k8s-gateway)

Ingress was moved from ingress-nginx to Envoy Gateway and the Gateway API, replacing per-app `Ingress` objects and their annotation soup with typed `HTTPRoute`, `SecurityPolicy` and `Gateway` resources. Two gateways serve the split: `envoy-internal` for LAN-only apps, `envoy-external` for internet-facing ones.

## Consequences

- `SecurityPolicy` gives forward auth a first-class resource targeting a named route, which is what later allowed the internal/external auth component split to collapse into one — see ADR-0014.
- `k8s-gateway` went with nginx; internal DNS is now CoreDNS plus `unifi-dns`.
- Routes are declared inline in each HelmRelease's `values.route` block rather than as standalone manifests — see ADR-0002.
- The long-form migration record, including the conversion pattern and per-app special cases, is [`kubernetes/apps/network/envoy-gateway/MIGRATION.md`](../../kubernetes/apps/network/envoy-gateway/MIGRATION.md). Its auth sections describe Authentik and are marked historical — do not copy them.
