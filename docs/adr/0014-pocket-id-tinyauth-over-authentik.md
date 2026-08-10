# pocket-id and tinyauth over Authentik

**Status:** accepted
**Date:** 2026-08-05
**Supersedes:** ADR-0006

SSO split into two purpose-built pieces: **pocket-id** as the cluster IdP with an operator that registers clients from `PocketIDOIDCClient` CRs, and **tinyauth** as a single forward-auth proxy for apps with no OIDC support. Client configuration became declarative and git-resident, which it never was under Authentik.

The **primary** driver was eliminating Plex federated OAuth as the means of authenticating users. That flow broke and locked every hosted service out at once — see ADR-0006. pocket-id holds its own accounts, so no third party sits between the operator and their cluster.

## Two auth paths — never both on one app

- **Native OIDC (preferred):** a `PocketIDOIDCClient` CR in the app's `app/` directory. No component. The operator registers the client and writes credentials into a Secret.
- **Forward auth (fallback):** the `components/auth` component in `ks.yaml`, creating a `SecurityPolicy` routing ext-auth to `tinyauth.security:3000`.

## Consequences

- `components/auth/{internal,external}` flattened to a single `components/auth`. The split existed only for Authentik's two outposts; tinyauth needs one backend, and the `SecurityPolicy` targets the app's HTTPRoute rather than the gateway, so one component covers both gateways.
- Generated OIDC credentials flow **outward** — a `PushSecret` backs them up to aKeyless. Writing an `ExternalSecret` to read them fails, because nothing has written the key yet.
- Forward-auth apps break Gatus route monitoring, since the auth redirect never returns 200. Those apps disable route monitoring and enable service monitoring instead.
- Apps with built-in auth get neither path.
