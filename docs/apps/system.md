# System

Infrastructure namespaces that keep the cluster running. You rarely interact with these directly — Flux manages them.

## kube-system

| App                      | Notes                                           |
| ------------------------ | ----------------------------------------------- |
| cilium                   | eBPF CNI + load balancer, replaces kube-proxy   |
| coredns                  | In-cluster DNS (10.43.0.10)                     |
| csi-driver-nfs           | NFS CSI driver for nfs-media storage class      |
| descheduler              | Rebalances pods across nodes                    |
| intel-gpu-resource-driver| Exposes Intel iGPU to pods (Plex, Jellyfin, Immich) |
| metrics-server           | Cluster resource metrics for HPA/kubectl top    |
| reloader                 | Restarts pods when their ConfigMaps or Secrets change |
| snapshot-controller      | Volume snapshot CRDs for VolSync                |
| spegel                   | P2P container image distribution between nodes  |

## cert-manager

| App          | Notes                                       |
| ------------ | ------------------------------------------- |
| cert-manager | TLS cert automation, Let's Encrypt DNS-01 via Cloudflare |

## external-secrets

| App              | Notes                                    |
| ---------------- | ---------------------------------------- |
| external-secrets | Operator — syncs aKeyless → K8s Secrets  |
| secret-stores    | ClusterSecretStore definitions, depends on external-secrets |

## flux-system

| App           | Notes                                     |
| ------------- | ----------------------------------------- |
| flux-operator | Flux OCI-based operator                   |
| flux-instance | The actual Flux deployment, depends on flux-operator |

## rook-ceph

| App       | Notes                                        |
| --------- | -------------------------------------------- |
| rook-ceph | Distributed block storage, ceph-ssd class    |

## openebs-system

| App     | Notes                                          |
| ------- | ---------------------------------------------- |
| openebs | Local hostpath provisioner, openebs-hostpath class |

## volsync-system

| App     | Notes                                                        |
| ------- | ------------------------------------------------------------ |
| volsync | PVC backup/restore orchestrator. Depends on keda, openebs, snapshot-controller. Uses keda/nfs-bkup-scaler. |

## system-upgrade

| App   | Notes                       |
| ----- | --------------------------- |
| tuppr | CNPG and Talos upgrade jobs |

## actions-runner-system

| App                        | Notes                              |
| -------------------------- | ---------------------------------- |
| actions-runner-controller  | GitHub Actions self-hosted runners, openebs-hostpath storage |
