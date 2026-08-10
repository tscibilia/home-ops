# Cross-cutting Interactions

Read this file when doing infrastructure migrations, removing or replacing components, or when something works in isolation but fails in context.

## ⚠️ Known Interaction Patterns

- **APIService conflicts:** `prometheus-adapter` registers the `custom.metrics.k8s.io` APIService. If another component registers the same one, they cannot coexist. Removing one requires `kubectl delete apiservice v1beta1.custom.metrics.k8s.io` before the other can register successfully.
- **Helm CRD uninstall gap:** Helm does NOT delete CRDs on chart uninstall. After removing a Helm release that owned CRDs, check `kubectl get crd | grep <pattern>` and delete orphans manually before reinstalling.
- **Flux delete vs suspend:** Removing a Kustomization from git destroys its managed resources on next reconciliation. `suspend: true` leaves resources in place. Use suspend for maintenance windows; git-delete for permanent removal.
- **Bash cwd resets per call:** The Bash tool working directory resets between every invocation. Never assume `cd` persisted — always use absolute paths.
- **Read tool path isolation:** Read tracks files by absolute path. A file read from `/home/tscibilia/home-ops/...` is a different tracked entry from the same file in a worktree path. Re-read after switching contexts.
