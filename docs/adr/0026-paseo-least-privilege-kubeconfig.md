# Paseo gets a least-privilege kubeconfig

**Status:** accepted
**Date:** 2026-11-20
**Supersedes:** [0023](0023-paseo-in-cluster-agent-host.md), kubeconfig bullet
**Relates to:** [0025](0025-paseo-talos-credentials.md)

ADR 0023 accepted cluster-admin credentials for the agent host and noted that a read-only ServiceAccount was "a one-file change if that trade becomes unacceptable". It is unacceptable: the guard against unsealing secrets was `tools.approval.eval: prompt`, which prompts on every `eval` call, cannot be granted for a session, does not cover `bash` (`kubectl get secret` ran free), and does not cover subagents at all (they run headless, so a prompt either fails or is skipped). A human prompt is not a boundary when the agent writes the code being approved.

## Decision

- The pod uses its own ServiceAccount (`paseo` in `ai`) through a static kubeconfig in the `paseo-configmap`: `tokenFile` and `certificate-authority` point at the projected service-account files, so kubelet rotates the token and no long-lived credential is copied.
- A `paseo-agent` ClusterRole grants `get`/`list`/`watch` on the cluster and `patch`/`update` on Flux resources. The core API group is enumerated because RBAC has no deny rules; every other group is wildcarded. **Secrets and ConfigMaps are not readable.**
- The admin kubeconfig (`/kubernetes/kubeconfig` + `/talos-m70q`) is no longer mounted in this pod. The aKeyless entry remains for other consumers.
- A user-level OMP hook (`~/.omp/agent/hooks/pre/secret-guard.ts`) confirms secret-shaped `bash`/`eval` calls and blocks them when no UI can answer. It is defense in depth, not the boundary.

## Alternatives rejected

- **Keep cluster-admin, tighten the eval prompt.** The prompt is per call, skippable only by approving arbitrary code, and bash is unguarded. It reduces neither reach nor risk.
- **Hook only.** Pattern matching catches accidents, not a deliberate bypass; `kubectl` remains able to read any Secret.
- **Admission policy to deny Secret reads.** Admission runs on writes, not GET/LIST, so it cannot gate reads.

## Consequences

- Secret metadata inspection from the pod is gone (`kubectl get secret` is denied). Operators inspect it from a workstation.
- Destructive recipes now require the operator or a temporary elevated kubeconfig: `apply-ks`, `delete-ks`, `node-shell`, `snapshot`/`restore`, `delete-pods`, `scale`, `annotate`, `exec`. Reconcile, suspend/resume, and all read paths still work.
- New API groups installed later are unreadable until added to the ClusterRole. The group list is explicit for this reason.
- The Talos credential from 0025 is unchanged and keeps `os:admin`; its blast radius is separate and is not reduced by this decision.
- Compromised agent code can still read what it is given: the GitHub token, the signing key, the provider keys. Those stay mounted because the workflows need them; the cluster secrets no longer are.
