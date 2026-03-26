# Daily Operations

## Merging Renovate PRs

Renovate opens PRs for dependency updates (container images, Helm charts, tools). Typical daily workflow:

1. Check the PR description for breaking changes or major version bumps
2. Merge via GitHub
3. Flux auto-reconciles within a few minutes
4. If impatient: `just kube ks-reconcile <ns> <app>`

## Common Workflows

| Task                          | Command                                     |
| ----------------------------- | ------------------------------------------- |
| Force sync a stuck resource   | `just kube sync-ks <ns> <name>`             |
| Reconcile from source         | `just kube ks-reconcile <ns> <name>`        |
| Restart all failed resources  | `just kube ks-restart` / `just kube hr-restart` |
| View a decoded secret         | `just kube view-secret <ns> <name>`         |
| Browse a PVC                  | `just kube browse-pvc <ns> <claim>`         |
| Snapshot a PVC                | `just kube snapshot <ns> <name>`            |
| List VolSync snapshots        | `just kube volsync-list <ns> <name>`        |

Full command reference: [Task Runner](task-runner.md)

## Health Checks

Quick commands to check cluster state:

```bash
# Failed Kustomizations
kubectl get ks -A | grep -v True

# Failed HelmReleases
kubectl get hr -A | grep -v True

# Ceph cluster health
kubectl get cephcluster -n rook-ceph

# CNPG database clusters
kubectl get cluster -n database

# Pod issues
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

## After a Push

Flux watches the repo and reconciles automatically. If something isn't picking up:

1. Check if the GitRepository source is synced: `just kube sync-git`
2. Force reconcile the specific app: `just kube ks-reconcile <ns> <app>`
3. If a HelmRelease is stuck in a bad state, delete it and let Flux recreate: `kubectl delete hr <name> -n <ns>`
