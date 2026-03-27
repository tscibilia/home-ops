# Home Ops

GitOps-managed Kubernetes cluster on three Lenovo M70q nodes, plus Docker services on TrueNAS, UnRaid, and a dedicated AI box.

## Why are you here?

<div class="grid cards" markdown>

-   :material-wrench:{ .lg .middle } **Something broke**

    ---

    Symptom → check → fix tables by area

    [:octicons-arrow-right-24: Troubleshooting](operations/troubleshooting.md)

-   :material-update:{ .lg .middle } **Daily upkeep**

    ---

    Merging Renovate PRs, health checks, common workflows

    [:octicons-arrow-right-24: Daily Ops](operations/daily-ops.md)

-   :material-apps:{ .lg .middle } **Add or modify an app**

    ---

    App catalog by namespace with config notes

    [:octicons-arrow-right-24: App Catalog](apps/)

-   :material-sitemap:{ .lg .middle } **Understand the cluster**

    ---

    Hardware, networking, storage, databases, GitOps

    [:octicons-arrow-right-24: Architecture](architecture.md)

-   :material-restart:{ .lg .middle } **Rebuild from scratch**

    ---

    Full disaster recovery and bootstrap process

    [:octicons-arrow-right-24: Bootstrap](bootstrap.md)

-   :material-console:{ .lg .middle } **Find a `just` command**

    ---

    All task runner commands for kube, talos, bootstrap

    [:octicons-arrow-right-24: Task Runner](operations/task-runner.md)

-   :material-docker:{ .lg .middle } **Docker services**

    ---

    TrueNAS, UnRaid, AI3090 — doco-cd managed

    [:octicons-arrow-right-24: Docker Services](docker/)

-   :material-heart-pulse:{ .lg .middle } **I'm family and need help**

    ---

    Plain-language guide for non-technical users

    [:octicons-arrow-right-24: Emergency](emergency.md)

</div>

## Quick Reference

| Item            | Value                                     |
| --------------- | ----------------------------------------- |
| **Cluster VIP** | 192.168.5.210                             |
| **Nodes**       | k8s-1 (.211), k8s-2 (.212), k8s-3 (.213) |
| **Domain**      | *.t0m.co (external), LAN via UniFi DNS    |
| **Source of truth** | This repo — Flux reconciles on push   |
| **Secrets**     | aKeyless → ExternalSecrets                |
