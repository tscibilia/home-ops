# Cluster Nodes

## ⚠️ Gotchas & Interactions

- **ai3090 GPU toleration required:** Any pod targeting ai3090 must include `tolerations: [{key: "nvidia.com/gpu", operator: "Exists", effect: "NoSchedule"}]` — there is no fallback node; the pod will be unschedulable without it.
- **openebs-hostpath is node-local:** If a pod using `openebs-hostpath` reschedules to a different node, the PVC data is inaccessible. Do not use for workloads that may move nodes.

## All Nodes (base config)
- Region: `topology.kubernetes.io/region: main`
- Primary network: `bond0` (192.168.5.0/24)
- Pod subnet: 10.42.0.0/16 | Service subnet: 10.43.0.0/16
- K8s API endpoint: 192.168.5.250:6443 (BGP-announced LoadBalancer)

---

## Control Plane

| Node   | IP (bond0, DHCP reservation) | Ceph IP (ceph0, static) | Special hardware |
|--------|------------------------------|-------------------------|------------------|
| k8s-1  | `192.168.5.211`              | `192.168.43.11/24`      | —                |
| k8s-2  | `192.168.5.212`              | `192.168.43.12/24`      | Zigbee — `feature.node.kubernetes.io/usb-zigbee: "true"` |
| k8s-3  | `192.168.5.213`              | `192.168.43.13/24`      | Z-Wave — `feature.node.kubernetes.io/usb-zwave: "true"`  |

---

## Worker: ai3090

**Canonical GPU workload pattern** (match llama-cpp / comfyui):
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
