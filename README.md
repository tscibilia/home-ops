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

[![Status Page](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fbadge%2F47d5c08e-21a9-41f1-b7fd-48092e%2FpXy582uA-2.shields&style=for-the-badge&logo=statuspage&logoColor=white&label=Status%20Page)](https://status.t0m.co)&nbsp;&nbsp;
[![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2Fd1cd3b92-cf69-4144-b5f2-9d044e983cff.shields&style=for-the-badge&logo=prometheus&logoColor=white&label=Alertmanager)](https://status.t0m.co)&nbsp;&nbsp;
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

👋 Welcome to my Home Operations repository. This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [Ansible](https://www.ansible.com/), [Terraform](https://www.terraform.io/), [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions).

---

### 🔎 Support

If you like this project, please consider supporting the work of [onedr0p](https://github.com/sponsors/onedr0p?frequency=one-time) and [bjw-s](https://github.com/sponsors/bjw-s?frequency=one-time).

---

### <img src="https://cdn.jsdelivr.net/gh/selfhst/icons/svg/kubernetes.svg" alt="☸️" width="20" height="20"> Kubernetes

My Kubernetes cluster is deployed with [Talos](https://www.talos.dev). This is a semi-hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate server with for NFS shares, bulk file storage and backups.

### Core Components

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): Self-hosted Github runners using [Renovate](https://github.com/renovatebot/renovate).
- [cert-manager](https://github.com/cert-manager/cert-manager): Creates SSL certificates for services in my cluster.
- [cilium](https://github.com/cilium/cilium): Kubernetes CNI.
- [cloudflared](https://github.com/cloudflare/cloudflared): Enables Cloudflare secure access to my routes.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Automatically syncs ingress DNS records to a DNS provider.
- [external-secrets](https://github.com/external-secrets/external-secrets): Managed Kubernetes secrets using [aKeyless](https://docs.akeyless.io/docs/kubernetes-plugins).
- [k8s-gateway](https://github.com/k8s-gateway/k8s_gateway): CoreDNS plugin to support internal ingress records.
- [nginx](https://github.com/nginx/nginx): Ingress controller and reverse proxy.
- [rook](https://github.com/rook/rook): Distributed block storage for peristent storage.
- [sops](https://github.com/getsops/sops): Managed secrets for Kubernetes which are commited to Git.
- [spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.
- [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller): Automatic Kubernetes and Talos upgrades.
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistent volume claims.

### Observability

- [alertmanager](https://github.com/prometheus/alertmanager): Handles processing and sending alerts.
- [fluent-bit](https://github.com/fluent/fluent-bit): Log processor.
- [gatus](https://github.com/TwiN/gatus): High level status dashboard.
- [grafana](https://github.com/grafana/grafana): Data visualization platform.
- [karma](https://github.com/prymitive/karma): Alertmanager dashboard, based on Cloudflare's unsee.
- [keda](https://github.com/kedacore/keda): Autoscales containers depending on event (i.e. NFS share is down)
- [kromgo](https://github.com/kashalls/kromgo): Expose prometheus metrics "safely" to GitHub.
- [ntfy](https://github.com/binwiederhier/ntfy): Handles receiving alerts on my devices.
- [silence-operator](https://github.com/giantswarm/silence-operator): Manages Alertmanager silences via custom resources.
- [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/): Database for logs.
- [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics): Time series database, drop-in replacement for Prometheus.

### Cloud Services

- [aKeyless](https://akeyless.io): Managing secrets via external-secrets.
- [Cloudflare](https://cloudflare.com/): Tunnels for exposing services and DNS provider.
- [Backblaze B2](https://www.backblaze.com/): Daily backups from volsync and cnpg.
- [SendGrid](https://sendgrid.com/): Sending system emails.

---

### :handshake: Thanks

This cluster comes from the people who have shared their clusters using the [k8s-at-home](https://github.com/topics/k8s-at-home) GitHub topic. Be sure to check out the awesome [Kubesearch](http://kubesearch.dev) tool for ideas on how to deploy applications or get ideas on what you can deploy.

There is a template over at [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) if you want to try and follow along with some of the practices I use here.

---

### 🔏 License

See [LICENSE](https://github.com/tscibilia/home-ops/blob/main/LICENSE)
