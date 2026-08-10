# Authentik for SSO

**Status:** superseded by ADR-0014
**Date:** 2025-05-01
**Reconstructed:** from `7f02baf9b` (2026-08-05), the commit that removed it

Authentik was adopted as the cluster identity provider, serving both native OIDC clients and forward-auth for apps with no OIDC support of their own.

Users authenticated through **Plex federated OAuth** as the primary login flow, rather than accounts held by the IdP itself.

## Consequences

- Authentik ran **two outposts**, which is why `components/auth` was originally split into `auth/internal` and `auth/external`. That split outlived its cause and was only flattened when Authentik was removed.
- Clients were configured through Authentik's UI and blueprints rather than declared in git, so client state was not reconstructible from the repo — a contributing motivation for the move to pocket-id's operator-managed CRs.
- **Total lockout (the reason it was replaced).** The Plex OAuth flow broke and locked every hosted service behind it at once, including the tooling needed to diagnose the problem — litellm was itself behind the same auth. The cause was never confirmed; either Plex or Authentik changed something in that specific flow. The load-bearing lesson is not about which was at fault: **identity was delegated to a third party outside this cluster, and there was no path back in when it failed.**

> **Reconstructed record.** Written after the fact from the removal commit. The reasoning for _adopting_ Authentik in 2025 is not recorded anywhere — treat the "why" above as inference, not contemporaneous rationale. The lockout account comes from the operator's recollection, not from logs.
