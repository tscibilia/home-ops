# home-ops rules

`AGENTS.md` is authoritative for this repo. These are the rules that matter to
every harness, including the host-wide ones:

- Many deployments store credentials in cleartext in `*/<app>.sqlite` (`settings`
  table). Never dump, copy, or `SELECT` that table; schema and non-credential
  columns only.
- Cluster credentials live in aKeyless/ESO. Never read values from Kubernetes
  Secrets, aKeyless, SOPS, Talos, app databases, config files, `.env`, volumes,
  or backups.
- Use `just kube ...` recipes for cluster operations; they consume credentials
  without printing them.
- If a value reaches output, stop and rotate at the source.
