# konflate (flate) over flux-local for local rendering

**Status:** accepted
**Date:** 2026-06-18
**Supersedes:** ADR-0001 (flux-local)

Local dry-run rendering moved from `flux-local` to `konflate` (`flate`), which resolves OCI chart sources and `postBuild` substitutions closer to what the cluster actually reconciles.

## Consequences

- `flate test all` and `flate build all` are the validation entry points; `FLATE_PATH` points at `kubernetes/flux/cluster`.
- Charts served by the private `ocharted` proxy need workstation OCI credentials. The OCIRepositories deliberately carry **no** `secretRef` — ocharted's `auth.bypassNetworks` exempts in-cluster Flux, but a workstation sits outside that CIDR. The fix is `just kube registry-auth`, never a manifest edit.
- CI and local validation share one tool, so a passing local run means something.
