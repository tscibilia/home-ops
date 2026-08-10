# towonel over Pangolin for public ingress

**Status:** accepted
**Date:** 2026-08-08
**Supersedes:** ADR-0009

Public ingress moved from Pangolin (Traefik + WireGuard) to towonel (SNI passthrough over iroh QUIC). DNS points at the VPS on :443, Caddy splits on SNI, and the connection is tunnelled to the in-cluster `envoy-external` gateway — which now terminates TLS itself, so certificates exist in one place instead of two.

## Consequences

- The VPS stops being a TLS endpoint and becomes a dumb SNI splitter; certificate management returns entirely to cert-manager in-cluster.
- `pangolin-operator`, its `NewtSite` and ExternalSecret, and the `tun.` / `api.tun.` / `doco.tun.` records were removed. The hub kept the `twnl.` hostname deliberately — renaming it would change the hub URL and edge advertised address, require a fresh certificate and invite, and repeat the cutover for no functional gain.
- The full migration narrative, phase sequencing, and a substantial troubleshooting catalogue live in [`docker/vps/MIGRATION.md`](../../docker/vps/MIGRATION.md). Read it before renaming a stack directory, editing an inline `configs:` block, or touching ufw / `DOCKER-USER` rules.
- Caddy 2.11+ rewrites Host on `https://` upstreams, which breaks UniFi's Origin check — `header_up Host {http.request.hostport}` is required there.
