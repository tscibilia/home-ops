# Pangolin for external ingress

**Status:** superseded by ADR-0015
**Date:** 2026-05-02
**Supersedes:** ADR-0001 (cloudflared)
**Reconstructed:** from `e95f52bd8` (2026-08-08), the commit that retired it

Public ingress moved off Cloudflare Tunnel onto a self-hosted VPS running Pangolin (Traefik + WireGuard), reached in-cluster by a `pangolin-operator` managing `NewtSite` resources. The motivation was owning the edge rather than terminating traffic in Cloudflare's network.

## Consequences

- Introduced the VPS as permanent infrastructure, along with the Ansible bootstrap and doco-cd GitOps that outlived Pangolin itself.
- Traefik terminated TLS at the VPS, so certificates had to exist in two places — a constraint towonel later removed by passing SNI through to the cluster.
- Left `tun.` / `api.tun.` / `doco.tun.` DNS records and a pocket-id OIDC client behind on removal.

> **Reconstructed record.** Written after the fact from the retirement commit. The full narrative of why Pangolin was chosen and how it behaved is in [`docker/vps/MIGRATION.md`](../../docker/vps/MIGRATION.md), which is contemporaneous and far more detailed than this record.
