---
name: update-docs
description: Use when adding an app to docs, updating docs after a PR or timeframe of changes, or modifying any file in docs/. Triggers on "add X to docs", "update docs", "document X", "reflect changes in docs".
---

# Maintaining Home-Ops Documentation

Reference skill for updating `docs/` to reflect cluster changes. Read the existing docs before making changes — follow established patterns exactly.

## Doc Structure

```
docs/
├── index.md                    # Intent-based landing page ("why am I here?")
├── architecture.md             # Hardware, networking, storage, databases, secrets, GitOps
├── bootstrap.md                # Disaster recovery / full cluster rebuild
├── emergency.md                # Family break-glass (plain language, no jargon)
├── apps/
│   ├── index.md                # Master catalog + "adding an app" guide + namespace table
│   ├── default.md              # Per-namespace app pages (see format below)
│   ├── media.md
│   ├── database.md
│   ├── home-automation.md
│   ├── observability.md
│   ├── network.md
│   └── system.md               # Groups infra namespaces (kube-system, cert-manager, flux, etc.)
├── docker/
│   └── index.md                # TrueNAS, UnRaid, AI3090 — doco-cd managed
└── operations/
    ├── daily-ops.md            # Renovate PRs, common workflows, health checks
    ├── troubleshooting.md      # Symptom → check → fix tables
    └── task-runner.md          # All just commands (kube, talos, bootstrap)
```

## Writing Style

- Casual, direct — like notes a person wrote for themselves
- Bullet lists and tables over prose. One idea per sentence.
- Active voice, present tense
- DRY: link to other docs or repo paths, don't repeat
- Only document non-obvious config. If someone needs to know what Sonarr does, they can Google it.
- **Never use**: "comprehensive", "leveraging", "robust", "seamless", "cutting-edge", or any LLM filler
- Hostnames over IPs for non-cluster machines (`.internal` domain)

## Adding an App to Docs

1. **Find the namespace page** in `docs/apps/` (e.g., `media.md` for a media app)
2. **Read the existing page** to match the exact table format
3. **Add a table row** with: App name | Storage class (or —) | Notes (non-obvious config only)
4. **Add a Config Notes section** only if the app has non-obvious setup:
   - VPN/Multus networking
   - Specific CNPG cluster or Dragonfly DB number
   - GPU access
   - External access specifics
   - Cross-namespace ReferenceGrant
   - Unusual dependencies or component usage
5. **Update the app count** in `docs/apps/index.md` namespace table
6. **Update `mkdocs.yml`** if adding a new namespace page (unlikely)

### What to check in the manifest

Look at the app's `ks.yaml` for:
- `dependsOn` — notable dependencies
- `components` — which reusable components (volsync, cnpg, ext-auth-*, keda)
- `postBuild.substitute` — any special substitutions

Look at `app/helmrelease.yaml` or `app/kustomization.yaml` for:
- Storage class overrides
- GPU resource requests
- Multus annotations (net1, 192.168.99.x)

### Per-namespace page format

```markdown
# Namespace Name

Namespace: `namespace-name`

| App    | Storage  | Notes                                |
| ------ | -------- | ------------------------------------ |
| app-a  | ceph-ssd | Brief non-obvious config             |
| app-b  | —        |                                      |

## Config Notes

### App A

Only if there's something non-obvious to explain. 2-3 sentences max.
```

## Updating Docs After Changes

When asked to update docs for a PR or timeframe:

1. **Check what changed**: `git log --oneline --since="<date>"` or `gh pr view <number>`
2. **Map changes to doc files**:
   - New/removed app → `apps/{namespace}.md` + `apps/index.md` count
   - Networking change → `architecture.md` networking section
   - Storage change → `architecture.md` storage section
   - New docker service → `docker/index.md`
   - New just command → `operations/task-runner.md`
   - Infrastructure change → `architecture.md` relevant section
3. **Read the affected doc file first** — match existing style exactly
4. **Make surgical edits** — don't rewrite sections that haven't changed
5. **Verify cross-links** still work if you renamed or moved anything

## Updating architecture.md

This file covers: Hardware, Networking (Physical / LAN DNS / Cluster / DNS / Certificates), Storage, Databases, Secrets, GitOps. Each section is self-contained. Edit only the relevant section — don't touch others.

## Updating emergency.md

Written for a non-technical family member. Plain language only. No jargon, no commands, no technical terms. If you're adding a family-facing service (like a new media app), add it to the "What This Cluster Runs" list.

## Common Mistakes

- Adding generic feature descriptions ("Sonarr manages TV series") — skip these, only document cluster-specific config
- Forgetting to update the app count in `apps/index.md`
- Using passive voice or filler prose
- Documenting IPs for docker machines instead of hostnames (use `.internal`)
- Adding a Config Notes entry for an app that has nothing non-obvious
