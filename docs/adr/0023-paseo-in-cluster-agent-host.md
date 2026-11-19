# Paseo runs in-cluster as the always-on agent host

**Status:** accepted
**Date:** 2026-11-18

Paseo is a daemon plus clients: the Windows app, the Linux app, the browser UI, and the phone all attach to one host. A WSL daemon dies with the workstation; the cluster daemon stays up and gives every client the same sessions and worktrees.

## Decision

- Run Paseo in the `ai` namespace on a `ceph-ssd` PVC. `/home/paseo` holds daemon state and is backed up by kopiur; `/workspace` holds git clones and worktrees and is not backed up.
- Build a child image from `ghcr.io/getpaseo/paseo` in a standalone `tscibilia/containers` repo. Bake OMP (`@oh-my-pi/pi-coding-agent`), OpenCode, Bun, Node 24, Python/uv, Go, mise, and the home-ops toolset. The upstream image deliberately ships no agent CLIs.
- Expose the daemon on `envoy-internal` at `paseo.${SECRET_DOMAIN}` with Paseo password auth, and enable the Paseo relay for off-LAN and phone use.
- Mount the admin kubeconfig assembled from `/kubernetes/kubeconfig` and the `/talos-m70q` cluster CA so agents can repair the cluster. Talos credentials are not mounted.
- Start with a blank `/workspace`; agents clone the repos they need. Work is git-mediated: uncommitted WSL edits are not visible to the pod.
- Sign commits with a dedicated SSH signing key stored in aKeyless, registered on an `obi-pod-kenobi` machine user rather than the personal account. Push with a fine-grained PAT owned by that machine user; the branch ruleset requires a signed PR, and the bot has no ruleset bypass.
- Let OMP's memini plugin derive the memory namespace from each repository's git remote/toplevel. Do not set `MEMINI_NAMESPACE`; the memini key's default namespace is only a fallback.

## Alternatives rejected

- **Jory's image as-is.** It lacks OMP, Bun, Node 24, Python/uv, and Go, and its tool pins are his. Extending a third-party personal image couples the cluster to his release cadence.
- **WSL daemon only.** It cannot satisfy "start at the desk, continue on the phone" when Windows sleeps or WSL shuts down.
- **No cluster credentials, or read-only.** Read-only cannot repair; the admin kubeconfig is the only way to give agents the same reach as the operator. The risk is accepted below.
- **Mirroring the WSL tree with rsync/Syncthing/NFS.** Divergence, locking, and NAT fragility outweigh the convenience. Git is the boundary.
- **Forward auth or OIDC.** The native clients authenticate to the daemon with a password over WebSocket; tinyauth in front of the HTTPRoute breaks that path. Paseo's password auth is the supported mechanism.

## Consequences

- The pod holds cluster-admin credentials. A prompt injection or malicious dependency can read them and take over the cluster. Treat the Paseo host as a privileged operator workstation, not a sandbox. Swapping to a read-only ServiceAccount is a one-file change if that trade becomes unacceptable.
- Sessions and worktrees live on the PVC. Moving a session between clients works because they share the daemon, not because files sync. A session started on a local WSL daemon does not migrate.
- The image is a maintained artifact. Renovate bumps Paseo, OpenCode, OMP, Bun, and the baked toolset; GitHub Actions publishes `ghcr.io/tscibilia/paseo`.
- `/workspace` is disposable. Only `/home/paseo` is backed up; repos are recoverable from GitHub.
- Relay is an outbound dependency on `relay.paseo.sh`. LAN clients should use the direct HTTPS host for latency.
