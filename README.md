<div align="center">

<img src="https://avatars.githubusercontent.com/u/61287648?s=200&v=4" align="center" width="144px" height="144px" alt="kubernetes"/>

## Home-Ops Kubernetes Repository

_... managed by Flux, Renovate and GitHub Actions_ :robot:

</div>

<br/>

<div align="center">

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue)](https://talos.dev  "Talos OS")&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=k8s)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=Flux)](https://fluxcd.io)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/github/actions/workflow/status/tscibilia/home-ops/renovate.yaml?branch=main&label=&logo=renovatebot&style=for-the-badge&color=blue)](https://github.com/tscibilia/home-ops/actions/workflows/renovate.yaml)

</div>


<div align="center">

[![Home-Internet](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F3%2F725515d4-5fdc-41ab-9e25-6c2b90732fb2.shields&style=for-the-badge&logo=ubiquiti&logoColor=white&label=Home%20Internet)](https://status.t0m.co)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F3%2F69edc917-4cd9-491b-ae51-18a25e193964.shields&style=for-the-badge&logo=prometheus&logoColor=white&label=Alertmanager)](https://status.t0m.co)&nbsp;&nbsp;
[![renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?style=for-the-badge&logo=renovatebot&logoColor=white)](https://github.com/renovatebot/renovate)

</div>

<div align="center">

[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo/)&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo/)&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;
[![Alerts](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.t0m.co%2Fcluster_alert_count&style=flat-square&label=Alerts)](https://github.com/kashalls/kromgo)

</div>

👋 Welcome to my Home Operations repository. This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [Ansible](https://www.ansible.com/),  [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions).

---

### 🔎 Support

If you like this project, please consider supporting the work of [onedr0p](https://github.com/sponsors/onedr0p?frequency=one-time) and [bjw-s](https://github.com/sponsors/bjw-s?frequency=one-time).

---

### <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/kubernetes.svg" alt="☸️" width="20" height="20"> Kubernetes

My Kubernetes cluster is a semi-hyper-converged cluster deployed with [Talos](https://www.talos.dev) on three [Proxmox](https://proxmox.com/) nodes. Workloads and block storage share the same available resources on my nodes backed by Ceph, while I have a separate server with NFS shares, bulk file storage, and backups.

### Core Components

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): Self-hosted Github runners using [Renovate](https://github.com/renovatebot/renovate).
- [cert-manager](https://github.com/cert-manager/cert-manager): Automates SSL/TLS certificate management.
- [cilium](https://github.com/cilium/cilium): eBPF-based Kubernetes CNI.
- [cloudflared](https://github.com/cloudflare/cloudflared): Enables Cloudflare's Zero Trust Network Access.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Automatically syncs DNS records to my DNS provider.
- [external-secrets](https://github.com/external-secrets/external-secrets): Managed Kubernetes secrets using [aKeyless](https://docs.akeyless.io/docs/kubernetes-plugins).
- [generic-device-plugin](https://github.com/squat/generic-device-plugin): Allocates linux devices to pods (squat.ai/tun).
- [k8s-gateway](https://github.com/k8s-gateway/k8s_gateway): CoreDNS plugin to support internal ingress records.
- [envoy-gateway](https://github.com/envoyproxy/gateway): Envoy Proxy to manage service-to-service communication and proxying.
- [nvidia-device-plugin](https://github.com/NVIDIA/k8s-device-plugin): Provides nvidia.com/gpu resource to pods.
- [openebs](https://github.com/openebs/openebs): CNI for ephemeral local storage.
- [rook](https://github.com/rook/rook): Distributed block storage for peristent storage.
- [sops](https://github.com/getsops/sops): Stores and manages encrypted secrets which are commited to Git.
- [spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.
- [tuppr](https://github.com/home-operations/tuppr): Automatic Talos and Kubernetes upgrades.
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistent volume claims.

### Observability

- [alertmanager](https://github.com/prometheus/alertmanager): Handles processing and sending alerts.
- [blackbox-exporter](https://github.com/prometheus/blackbox_exporter): Probe external endpoint ports for success/failure.
- [fluent-bit](https://github.com/fluent/fluent-bit): Log processor.
- [gatus](https://github.com/TwiN/gatus): High level status dashboard.
- [grafana](https://github.com/grafana/grafana): Data visualization platform.
- [karma](https://github.com/prymitive/karma): Alertmanager dashboard, based on Cloudflare's unsee.
- [keda](https://github.com/kedacore/keda): Autoscales containers on events (i.e. blackbox reports NFS share is down).
- [kromgo](https://github.com/kashalls/kromgo): Expose prometheus metrics "safely" to GitHub.
- [silence-operator](https://github.com/giantswarm/silence-operator): Manages Alertmanager silences via custom resources.
- [unpoller](https://github.com/unpoller/unpoller): Collect UniFi Controller data for Prometheus.
- [victoriaLogs](https://docs.victoriametrics.com/victorialogs/): Database for logs.
- [victoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics): Time series database, drop-in replacement for Prometheus.

### Cloud Services

- [aKeyless](https://akeyless.io): Managing secrets via external-secrets.
- [Cloudflare](https://cloudflare.com/): Tunnels for exposing services and DNS provider.
- [Cloudinary](https://cloudinary.com/): Image hosting for plex newsletter posters.
- [Backblaze B2](https://www.backblaze.com/): Daily backups from volsync and cnpg.
- [Amazon SES](https://aws.amazon.com/ses/): Sending system emails.
- [Pushover](https://pushover.net/): Sending push notifications to mobile.

---

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches the clusters in my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my clusters based on the state of my Git repository.

The way Flux works for me here is it will recursively search the `kubernetes/apps` folder until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it. That aforementioned `kustomization.yaml` will generally only have a namespace resource and one or many Flux kustomizations (`ks.yaml`). Under the control of those Flux kustomizations there will be a `HelmRelease` or other resources related to the application which will be applied.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When I merge those PRs, Flux applies the changes to my cluster.

[Just](https://github.com/casey/just) files are used to call on repetative commands or batches of commands, grouped into receipes. The root directory has a `.justfile` which imports three modules (bootstrap, kube, and talos) while providing shared logging utilities and enforces bash error handling.

### Directories

This Git repository contains the following directories.

```sh
📁 bootstrap      # exactly what it sounds like
└── 📁 scripts    # some janky hacks for my setup
📁 kubernetes
├── 📁 apps       # applications organized by namespace
├── 📁 components # re-useable kustomize components
└── 📁 flux       # flux system configuration
📁 talos          # node OS configurations
```

---

### :handshake: Thanks

This cluster comes from the people who have shared their clusters using the [k8s-at-home](https://github.com/topics/k8s-at-home) GitHub topic. Be sure to check out the awesome [Kubesearch](http://kubesearch.dev) tool for ideas on how to deploy applications or get ideas on what you can deploy.

There is a template over at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) if you want to try and follow along with some of the practices I use here.

---

### 🔏 License

See [LICENSE](https://github.com/tscibilia/home-ops/blob/main/LICENSE)

___

<div align="center">

[![DeepWiki](https://img.shields.io/badge/deepwiki-purple?label=&logo=deepl&style=for-the-badge&logoColor=white)](https://deepwiki.com/tscibilia/home-ops)

</div>