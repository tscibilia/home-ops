# Teardown & Replacement

**When to use:** remove, replace, teardown, migrate, apiservice, crd, conflict, operator

Read this before removing or replacing cluster infrastructure — an operator, a CRD-owning chart, a metrics provider. Everything here is a trap that only appears on the way _out_, when the thing being removed leaves state behind that blocks its successor.

**What belongs here:** a fact about removing or swapping infrastructure that no single subsystem owns. If the fact is about _using_ a thing, it belongs in that thing's file — `components.md`, `storage.md`, `networking.md`. If it only bites during teardown, it belongs here.

## ⚠️ Teardown Traps

- **APIService conflicts:** `prometheus-adapter` registers the `custom.metrics.k8s.io` APIService. Two providers cannot both hold it, so swapping metrics providers requires `kubectl delete apiservice v1beta1.custom.metrics.k8s.io` before the replacement can register. This is what made the KEDA → zeroscaler swap non-atomic ([ADR-0010](../adr/0010-zeroscaler-over-keda.md)).
- **Helm CRD uninstall gap:** Helm does NOT delete CRDs on chart uninstall. After removing a release that owned CRDs, check `kubectl get crd | grep <pattern>` and delete orphans by hand — a reinstall will otherwise adopt stale schemas.
- **Flux delete vs suspend:** Removing a Kustomization from git destroys its managed resources on the next reconciliation. `suspend: true` leaves them in place. Suspend for maintenance windows; git-delete only for permanent removal.
