## Authentik
---

Not sure where I grabbed my inpiration from, but it's only working for OIDC connections.
- I can't get the embedded outpost to proxy requests.
- Someone had a setup using common components, that might help?
  - https://github.com/JJGadgets/Biohazard/blob/main/kube/deploy/apps/authentik/forward-auth/ingress.yaml

## TODOs
- Look at webfinger ingress https://webfinger.net/
- Establish init-db for bootstrapping (even though I'll probably never need to use it)
- Fix external-secrets for consistent naming OIDC/OAUTH/SSO etc