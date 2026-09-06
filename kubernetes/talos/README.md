# Talos Configuration

## Overview

This directory manages the declarative [Talos Linux](https://www.talos.dev) machine configuration for the cluster,
built from composable multi-document patches. Nothing in this directory is applied automatically; configs are
rendered on demand and pushed to nodes with `talosctl`. node configuration for the .

## Layout

| Path                                    | Purpose                                                       |
| --------------------------------------- | ------------------------------------------------------------- |
| `cluster.yaml.j2`                       | Documents applied to every node                               |
| `controlplane.yaml.j2`                  | Control-plane-only documents, including `machine.type`        |
| `workers.yaml.j2`                       | Worker-only documents                                         |
| `nodes/<role>/<node>.yaml.j2`           | Per-node documents (hostname, addresses, BGP router ID, zone) |
| `nodes/<role>/<node>.schematic.yaml.j2` | Optional per-node schematic override                          |
| `schematic.yaml.j2`                     | Shared [Image Factory](https://factory.talos.dev) schematic   |
| `mod.just`                              | Recipes (`just talos ...`)                                    |

## Rendering

`just talos render-config <node>` builds the final machine config in three layers:

```
talosctl machineconfig patch <(cluster.yaml.j2) \
    -p @<(controlplane.yaml.j2 | workers.yaml.j2) \
    -p @<(nodes/<role>/<node>.yaml.j2)
```

Each layer passes through `minijinja-cli` (strict Jinja templating; the schematic ID arrives as a `-D` define)
and `akeyless inject` (secret resolution) before `talosctl` merges them. Later patches strategically merge into
earlier ones: documents with the same kind/name are deep-merged, new documents are appended.

Two conventions keep the layers honest:

- **Directory placement is the single source of truth for a node's role.** The role patch is chosen
  by which `nodes/<role>/` directory contains the node file, and `machine.type` is set by the role
  patch, not the node file. A node cannot claim one role by filename and another by content.
- **Secrets never live in this repo.** All sensitive values are `ak://<name>/.../<secret>`
  references resolved at render time.

## Schematics

The schematic defines the Image Factory build (system extensions, kernel args). `just talos
schematic-id` POSTs it to the factory and gets back a content-addressed ID, which is templated into
the `UnattendedInstallConfig` installer image and used by `download-image` and `upgrade-node`.

Resolution is per node: `nodes/<role>/<node>.schematic.yaml.j2` wins when present, otherwise the
shared `schematic.yaml.j2` applies. Overrides are complete files, not deltas; they exist for nodes
whose hardware diverges from the fleet. No overrides exist today.

## Commands

| Command                           | Purpose                                                |
| --------------------------------- | ------------------------------------------------------ |
| `just talos apply-node <node>`    | Render and apply config to a node (live, no reboot)    |
| `just talos render-config <node>` | Render the full config for a node (dry-run)            |
| `just talos upgrade-node <node>`  | Upgrade Talos version on a node (reboots)              |
| `just talos schematic-id <node>`  | Get the current factory schematic hash for a node      |
| `just talos reboot-node <node>`   | Reboot a node (powercycle)                             |
| `just talos machine-image <node>` | Get the install image URL for a node (schematic-aware) |

## tuppr — Automatic Upgrades

[Tuppr](https://github.com/home-operations/tuppr) is the upgrade controller. It manages Talos and
Kubernetes version upgrades through a `TalosUpgrade` CR. See `apps/system-upgrade/tuppr/`.

To trigger a Talos upgrade:

1. Bump the installer version in `cluster.yaml.j2` (`UnattendedInstallConfig`) and `upgrades/talosupgrade.yaml`
2. Commit and push — Flux reconciles, tuppr picks up the change
3. tuppr upgrades nodes one by one (controller first, workers last)

## Gotchas

- `machine.ca` and `cluster.ca` merge as a cert+key **unit**: a patch supplying only `key` blanks
  `crt`. This is why `controlplane.yaml.j2` repeats the `crt` references alongside the keys.
- Rendering a worker before `workers.yaml.j2` and `nodes/workers/` exist fails loudly. Adding the
  first worker means creating `workers.yaml.j2` (with `machine: { type: worker }` and a `ca` block
  carrying `crt` only) plus `nodes/workers/<node>.yaml.j2`.

### Talos v1.13.7 Upgrade Blocked — Schematic Hash Mismatch

**Symptom (2026-07-30):** tuppr stuck in `Pending → BuildTargetImage`:

> install image `.../85b8bbd7...:v1.13.6` does not embed the runtime schematic `5c952bad...`

**Root Cause:**
Commit `71d239a8` (Jun 23) refactored two separate schematic files
(`controlplane/schematic.yaml.j2`, `worker/schematic.yaml.j2`) into one combined `nodes/schematic.yaml.j2`.
During the merge, the **extension list order for control planes changed**, therefore the schematic hash differed:

**Lesson:** When refactoring schematic templates, diff the **rendered output** (not just the Jinja2 template)
