# home-ops hard rules

- Many deployments may store credentials in cleartext in `*/<app-name>.sqlite` (`settings` table). Never dump, copy, or `SELECT` that table; schema and non-credential columns only.
- Cluster credentials live in aKeyless/ESO. Never read values from Kubernetes Secrets, aKeyless, SOPS, Talos, app databases, config files, `.env`, volumes, or backups.
- If a value reaches output, stop and rotate at the source.
