# Troubleshooting

Organized by area. Each entry: what you see, what to check, how to fix it.

## Flux / GitOps

| Symptom | Check | Fix |
| ------- | ----- | --- |
| App not updating after push | `kubectl get ks -A \| grep -v True` | `just kube ks-reconcile <ns> <app>` |
| HelmRelease stuck | `kubectl get hr -n <ns> <name>` | Delete the HR: `kubectl delete hr <name> -n <ns>`, Flux recreates it |
| `kubectl edit` changes reverted | Expected — Flux owns all state | Edit in Git, push, reconcile |
| Kustomization dependency failed | Check the dependency: `kubectl get ks -n <dep-ns> <dep-name>` | Fix the upstream dependency first |

## Networking

| Symptom | Check | Fix |
| ------- | ----- | --- |
| LoadBalancer IP unreachable | `kubectl get svc -A -o wide \| grep LoadBalancer` | Check `CiliumL2AnnouncementPolicy` and `CiliumLoadBalancerIPPool` |
| External DNS not resolving | `kubectl logs -n network deploy/external-dns` | Verify Cloudflare API token in secret, check HTTPRoute exists |
| LAN DNS not resolving | `kubectl logs -n network deploy/unifi-dns` | Check UniFi controller connectivity |
| External access broken | `kubectl get pods -n network -l app=cloudflared` | Verify cloudflared tunnel status, check Cloudflare dashboard |
| Cert not issuing | `kubectl get cert -A`, `kubectl get challenges -A` | Check cert-manager logs, verify Cloudflare DNS-01 permissions |

**Remember**: There is no kube-proxy. Cilium is the eBPF replacement. Use `cilium` CLI or Hubble for network debugging, not iptables.

## Storage

| Symptom | Check | Fix |
| ------- | ----- | --- |
| Ceph cluster degraded | `kubectl get cephcluster -n rook-ceph` | Check OSD pods, node status, disk health via Scrutiny |
| PVC stuck Pending | `kubectl describe pvc -n <ns> <name>` | Verify storage class exists, Ceph has capacity |
| NFS mount errors | Check pod events: `kubectl describe pod -n <ns> <pod>` | Verify TrueNAS is reachable, NFS share exists |
| VolSync backup failing | `kubectl get replicationsource -n <ns>` | Check restic repo locks: `just kube volsync-unlock` |
| VolSync restore needed | `just kube volsync-list <ns> <name>` | `just kube volsync-restore <ns> <name> <previous>` |

## CNPG

| Symptom | Check | Fix |
| ------- | ----- | --- |
| Cluster unhealthy | `kubectl get cluster -n database` | Check `.status.conditions`, inspect pod logs |
| Wrong CNPG image used | Verify cluster name | `pgsql-cluster` = standard PG17, `immich17` = vectorchord |
| Need full recovery | Backups are in B2 | `just bootstrap cnpg` — don't manually recreate clusters |
| Connection refused | Check endpoint: `kubectl get svc -n database \| grep rw` | Always use the `-rw` service for app connections |

## Talos

| Symptom | Check | Fix |
| ------- | ----- | --- |
| Can't SSH to node | Expected — Talos has no SSH | Use `talosctl -n <node-ip>` for all node access |
| Config change needed | — | Edit templates in `kubernetes/talos/`, then `just talos apply-node <node>` |
| Upgrade needed | Check current version: `talosctl version` | Upgrade order: Talos first (`just talos upgrade-node`), then K8s (`just talos upgrade-k8s`) |
| Node stuck | `talosctl dmesg -n <node-ip>` | Try `just talos reboot-node <node>` |
