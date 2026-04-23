# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview
Home-ops monorepo. K8s cluster (Talos + Flux CD + Helm/Kustomize) on 3 bare-metal nodes with Rook Ceph.
**Stack:** Talos Linux → Kubernetes → Flux CD → Helm/Kustomize
**Layout:** `/kubernetes/` (apps, talos, bootstrap), `/docker/` (server configs), `docs/` (MKDocs).

## Karpathy Skills
**Behavioral guidelines to reduce common LLM coding mistakes. Bias toward caution over speed.**

### 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If a simpler approach exists, push back when warranted.
- If something is unclear, stop. Name what's confusing and ask.

### 2. Simplicity First
**Minimum code that solves the problem. Nothing speculative.**
- No features, abstractions, or configurability beyond what was asked.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Ask: "Would a senior engineer say this is overcomplicated?"

### 3. Surgical Changes
**Touch only what you must. Clean up only your own mess.**
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor working code. Match existing style.
- When changes create orphans: remove imports/variables/funcs that *your* changes made unused.
- Do not remove pre-existing dead code unless asked.
- Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution
**Define success criteria. Loop until verified.**
- Transform tasks into verifiable goals (e.g., "Fix bug" → "Write failing test, then make it pass").
- For multi-step tasks, state a brief plan:
  1. [Step] → verify: [check]
  2. [Step] → verify: [check]

## Task Runner & Workflow
`just` modules: `bootstrap`, `kube`, `talos`.

**`just kube` (most used):**
- `sync-ks/hr/es <ns> <name>` — force sync resource
- `ks-reconcile/hr-reconcile <ns> <name>` — reconcile from source
- `ks-reconcile-all/hr-reconcile-all` — reconcile everything
- `ks-restart/hr-restart <ns>` — suspend/resume failed resources
- `apply-ks <ns> <ks>` — validate locally with flux-local
- `node-shell <node>`, `view-secret <ns> <secret>`, `snapshot <ns> <name>`

**Workflow:**
1. New app: use `add-app` skill
2. Secrets: aKeyless → `externalsecret.yaml`
3. Test/Sync: `apply-ks` → `ks-reconcile`
4. Docs: use `update-docs` skill

**`just talos`:** `apply-node <node>`, `upgrade-node <node>/upgrade-k8s <version>`

## Architecture & Structure
**Monorepo Layout:**
```
docker                        # Server configs (unraid, truenas, ai3090)
docs                          # MKDocs documentation
kubernetes                    # K8s cluster
├── apps                      # Applications organized by namespace
│   ├── default               # General purpose self-hosted applications
│   ├── ...
│   └── volsync-system        # VolSync for PVC backup and restore
├── bootstrap                 # Directory to bootstrap Talos nodes
│   ├── cnpg                  # CNPG patches applied during cluster bootstrap
│   ├── helmfile.d            # Helmreleases required for cluster bootstrap
│   ├── scripts               # Bootstrap helper scripts
│   └── mod.just              # .justfile Bootstrap module
├── components                # Reusable Kustomize components for apps
├── flux                      # Flux CD system configuration
├── talos                     # Talos node OS configurations
│   ├── nodes                 # Talos node-specific configuration overrides
│   ├── machineconfig.yaml.j2 # Jinja2 template for base Talos machine config
│   ├── mod.just              # .justfile Talos module
│   └── schematic.yaml.j2     # Talos image factory schematic template
└── mod.just                  # .justfile Kubernetes module
```
*(For detailed references, prioritize reading the relevant sub-directory's `README.md`, e.g., `kubernetes/bootstrap/cnpg/README.md`)*

**Apps:** `kubernetes/apps/{namespace}/{app-name}/`
- `app/` (kustomization, helmrelease, ocirepository, externalsecret)
- `ks.yaml` (Flux Kustomization entry point: defines `dependsOn`, `substitutions`, `components`)

**Components (`/kubernetes/components/`):** `common/`, `cnpg/`, `ext-auth-internal/`, `ext-auth-external/`, `keda/`, `volsync/`.

**Conventions:**
- YAML anchors (`&app` → `*app`)
- Renovate: `# renovate: datasource=docker depName=...`
- `configMapGenerator` for embedded files
- Always declare `dependsOn` in `ks.yaml`

**Storage Classes:**
- `ceph-ssd` (default) — Rook Ceph, all persistent workloads
- `openebs-hostpath` — local node storage (CNPG, logs, actions-runner)
- `nfs-media` — external NFS for media library

**Infrastructure:**
- **CNPG Clusters:** `pgsql-cluster` (PG17), `immich17` (vectorchord). Use `<cluster>-rw.database.svc.cluster.local`.
- **Networking:** SSO via `ext-auth-external`/`internal`. Ingress via `envoy-external`/`internal`.
- **Secrets:** Synced via `ExternalSecret` from aKeyless.

## Commit Protocol
Before requesting a commit, ensure:
- **Validation**: YAML files are schema-validated, linted, and formatted.
- **Constraint**: The agent must NOT attempt to commit directly (GPG restriction).
- **Handoff**: Provide a complete, formatted commit message for user review.

## Troubleshooting
- **Flux/GitOps**: `kubectl edit` is ephemeral; always use `git`. Check failures: `mise && kubectl get ks -A | grep -v True`.
- **Talos**: No SSH. Use `talosctl`. Edit templates in `kubernetes/talos/`, then `just talos apply-node <node>`.
- **Cilium**: eBPF replacement for kube-proxy. Use `cilium` CLI for network debugging.
- **CNPG**: Use `-rw` endpoint for app connections. Check health: `kubectl get cluster -n database`.
- **VolSync**: Restore via `just kube volsync-restore <ns> <name> <previous>`.

## Active Work
Check `../ACTIVE-WIP.md` for: **In Progress**, **Known Issues**, **Blocked**, or **Resolved**.
