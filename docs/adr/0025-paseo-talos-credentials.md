# Paseo receives Talos credentials from a Talos ServiceAccount

**Status:** accepted
**Date:** 2026-11-19
**Relates to:** ADR-0023

ADR-0023 gave the Paseo pod an admin kubeconfig so agents can repair the cluster, and stated that Talos credentials are not mounted. That left `just talos` unusable inside the pod: every recipe derives endpoints from `talosctl config info` and then calls the Talos API. The Talos API access feature already permits `os:admin` for the `ai` namespace, so the credential can be minted on demand instead of copied.

## Decision

- Declare a `talos.dev/v1alpha1` `ServiceAccount` named `paseo-talosconfig` in the `ai` namespace with `roles: [os:admin]`. Talos reconciles it from its own controller; no operator is installed for this CRD.
- Project the generated secret's `config` key into `/etc/paseo/talosconfig`, next to the kubeconfig, in the same projected volume.
- Give each worktree `kubeconfig` and `talosconfig` at its root through the `worktree.setup` hook in the tracked `paseo.json`: link from the project clone when the file is there, otherwise from `/etc/paseo`. `.mise.toml` already points `KUBECONFIG` and `TALOSCONFIG` at those two root paths, so no recipe or environment variable changes.
- Use `os:admin`, not `os:reader`, because `just talos apply-node` calls `apply-config`.

## Alternatives rejected

- **Render a talosconfig from aKeyless `/talos-m70q`.** That path holds the cluster CA certificate and the CA private key, not a client certificate. Producing one means signing an `os:admin` client certificate from the CA key inside the pod, and handling the CA key where an agent can read it.
- **Copy the operator's admin talosconfig into aKeyless.** Static long-lived credential, manual rotation, and a second copy of a cluster-wide secret.
- **`os:reader` only.** It cannot apply machine configuration, so the recipes that motivated the change would still fail.
- **Mount the credentials inside the project clone at `/home/paseo/workspace/home-ops/kubeconfig`.** A `subPath` file mount pre-creates the project directory. Paseo clones by renaming a staging directory onto that path, which fails when the target already exists, so a fresh PVC could never clone the repository.
- **Per-environment rules.** Copying files at container start or branching on the host would make the pod behave differently from the workstation. One hook in the committed `paseo.json` runs on both.

## Consequences

- The pod can now reboot, reset, and reconfigure any node. Its blast radius grows from cluster-admin to cluster-admin plus Talos, which is the same class of trust ADR-0023 already accepted for the kubeconfig.
- Talos rotates the service-account certificate. The secret is a projected volume, so the mounted file updates through the `..data` swap and worktree symlinks keep resolving; no pod restart is required.
- Worktree creation depends on the hook. A checkout without a `paseo.json` `worktree.setup` entry gets no credentials, and agents in the project clone rely on the one-time links that bootstrap creates.
- The `ai` namespace must stay in `allowedKubernetesNamespaces` in `KubeTalosAPIAccessConfig`, with `os:admin` in `allowedRoles`. Removing either breaks the pod's Talos access without touching its manifests.
