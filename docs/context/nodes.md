# Cluster Nodes

## ⚠️ Gotchas & Interactions

- **ai3090 GPU toleration required:** Any pod targeting ai3090 must include `tolerations: [{key: "nvidia.com/gpu", operator: "Exists", effect: "NoSchedule"}]` — there is no fallback node; the pod will be unschedulable without it.
- **openebs-hostpath is node-local:** If a pod using `openebs-hostpath` reschedules to a different node, the PVC data is inaccessible. Do not use for workloads that may move nodes.
- **Kubelet image GC must stay under Ceph's threshold:** `/var` (400 GiB, `nvme0n1p4`) holds both the containerd image store and the Ceph MON store (`/var/lib/rook/mon-*`). Ceph fires `MON_DISK_LOW` at 70% used, so `imageGCHighThresholdPercent` is 45 / low 35 — raising it above 70 means kubelet never prunes and the MON warning fires instead. 45/35 rather than 60/50 because the image store grows ~10 GB/day (Flux image bumps, ~420 cached digests vs ~180 in use) and 60% left too little room for the double image set an upgrade pull storm creates.
- **Pod slots are the real node limit:** kubelet `maxPods` is 150 (default 110). At 110, ~240 pods over 3 schedulable nodes meant every node held ~80, so evacuating one needed 120 slots on each of the other two and new pods went `Pending` with `Too many pods`. A cordon is not an eviction signal: descheduler's `RemovePodsViolatingNodeTaints` excludes `node.kubernetes.io/unschedulable`, so cordoning one node no longer evacuates all of it onto the others.
- **`local-hdd` is ai3090-only:** Static PV on the ai3090 HDD (`/var/mnt/local-hdd`), no dynamic provisioning — a pod using it is pinned to that node. See `storage.md`.

## All Nodes (base config)

- Region: `topology.kubernetes.io/region: main`
- Zone: `topology.kubernetes.io/zone: m` (control plane) / `w` (worker ai3090)
- Primary network: `bond0` (192.168.5.0/24)
- Pod subnet: 10.42.0.0/16 | Service subnet: 10.43.0.0/16
- K8s API endpoint: k8s.internal:6443 (BGP-announced LoadBalancer, 192.168.42.50)
- `node.kubernetes.io/gpu: "true"` label set on ALL nodes in base config (does NOT mean the node has a GPU — only ai3090 actually has one)

---

## Control Plane

| Node  | IP (bond0, DHCP reservation) | Ceph IP (ceph0, static) | Special hardware                                         |
| ----- | ---------------------------- | ----------------------- | -------------------------------------------------------- |
| k8s-1 | `192.168.5.211`              | `192.168.43.11/24`      | —                                                        |
| k8s-2 | `192.168.5.212`              | `192.168.43.12/24`      | Zigbee — `feature.node.kubernetes.io/usb-zigbee: "true"` |
| k8s-3 | `192.168.5.213`              | `192.168.43.13/24`      | Z-Wave — `feature.node.kubernetes.io/usb-zwave: "true"`  |

---

## Worker: ai3090

**Canonical GPU workload pattern** (match llmkube InferenceServices / comfyui):

```yaml
defaultPodOptions:
    runtimeClassName: nvidia
    nodeSelector:
        feature.node.kubernetes.io/pci-10de.present: "true"
    tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
resources:
    limits:
        nvidia.com/gpu: "1"
```
