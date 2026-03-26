# Home Ops

GitOps-managed Kubernetes cluster on three Lenovo M70q nodes, plus Docker services on TrueNAS, UnRaid, and a dedicated AI box.

## Why are you here?

| I need to...                         | Go here                                          |
| ------------------------------------ | ------------------------------------------------ |
| Fix something that broke             | [Troubleshooting](operations/troubleshooting.md) |
| Merge a Renovate PR / daily upkeep   | [Daily Ops](operations/daily-ops.md)             |
| Add or modify an application         | [App Catalog](apps/)                             |
| Understand how the cluster works     | [Architecture](architecture.md)                  |
| Rebuild the cluster from scratch     | [Bootstrap](bootstrap.md)                        |
| Find a `just` command                | [Task Runner](operations/task-runner.md)         |
| I'm family and need help             | [Emergency](emergency.md)                        |

## Quick Reference

| Item       | Value                                              |
| ---------- | -------------------------------------------------- |
| Cluster VIP | 192.168.5.210                                     |
| Nodes      | k8s-1 (.211), k8s-2 (.212), k8s-3 (.213)          |
| Domain     | *.t0m.co (external), LAN via UniFi DNS             |
| Source of truth | This repo — Flux reconciles on push            |
| Secrets    | aKeyless → ExternalSecrets                         |
