# AGENTS.md

## Project Overview

Home-ops monorepo. K8s cluster (Talos + Flux CD + Helm/Kustomize) on 3 bare-metal nodes with Rook Ceph.
**Stack:** Talos Linux → Kubernetes → Flux CD → Helm/Kustomize
**Server-side rendering:** `flate` (konflate) — replaces `flux-local` for dry-run validation.

## Standing Rules

**Karpathy guidelines govern every change** — full text `.agents/skills/karpathy-guidelines/SKILL.md`:

1. **Think before coding** — state assumptions; if unclear, stop and ask; don't pick silently between readings.
2. **Simplicity first** — minimum code that solves it; nothing speculative.
3. **Surgical changes** — touch only what you must; no adjacent cleanup; match existing style.
4. **Goal-driven** — state plan as `[step] → verify: [check]`; every changed line traces to the request.

Report concisely — sacrifice grammar for the sake of concision.

**Skill config:**

- **Domain docs** — [`CONTEXT.md`](CONTEXT.md) is the map (glossary, state routing, ADR index). `docs/context/` = state, `docs/adr/` = decisions. See `docs/agents/domain.md`.
- **Issue tracker** — GitHub Issues on `tscibilia/home-ops`, via `gh`. See `docs/agents/issue-tracker.md`.
- **Triage labels** — five canonical roles, default label strings. See `docs/agents/triage-labels.md`.

## Task Runner & Workflow

`just` modules: `bootstrap`, `kube`, `talos`, `ansible`. Using `just <module-name>` will list available commands.

**`just kube` (most used):**

- `sync <hr|ks|es|gitrepo|ocirepo> [<ns> <app>]` — force sync resource (or all)
- `reconcile-ks/reconcile-hr [<ns> <app>]` — reconcile from source (or all)
- `restart-ks/restart-hr` — suspend/resume failed resources
- `node-shell <node>`, `snapshot [<ns> <app>]`
- `apply-ks <ns> <ks>`, `delete-ks <ns> <ks>` — render via `flate` and apply/delete (⚠️ touches live cluster)

**Local validation (no cluster required):**

- `flate test all` — validate all Kustomizations, HelmReleases, sources
- `flate build all` — render full cluster to YAML
- `just kube registry-auth` — one-time per machine; required before the first `flate` run (see Troubleshooting)

**Workflow:**

1. New app: follow `.agents/skills/add-app/SKILL.md`
2. Secrets: aKeyless → `externalsecret.yaml`
3. Provide human in the loop with commit message
4. Docs: update the affected `docs/context/` file(s) in the same change. If the change involved a decision — a trade-off with real alternatives that's costly to reverse — add an ADR instead of writing the rationale into a context file.

## Architecture & Structure

**Monorepo Layout:**

```text
CONTEXT.md                    # Map: glossary · state routing · ADR index — read first
docker/                       # Server configs (unraid, truenas, vps)
docs/                         # context/ (state) · adr/ (decisions) · agents/ (skill config) · WORKLOG.md
kubernetes/
├── apps/{namespace}/{app}/   # see Apps below
├── bootstrap/                # cnpg/ patches, kustomize/ secrets template, scripts/
│   └── helmfile/             # chart sources resolved from app OCIRepositories
├── components/               # reusable Kustomize components
├── flux/                     # Flux CD system config
└── talos/                    # nodes/ overrides; *.yaml.j2 render machineconfig + schematic
```

_(For sub-directory specifics not covered by `docs/context/`, read that directory's `README.md`, e.g. `kubernetes/bootstrap/cnpg/README.md`.)_

**Apps:** `kubernetes/apps/{namespace}/{app-name}/`

- `app/` (kustomization, helmrelease, ocirepository, externalsecret)
- `ks.yaml` (Flux Kustomization entry point: defines `dependsOn`, `substitutions`, `components`)

**Storage Classes:**

- `ceph-ssd` (default) — Rook Ceph, all persistent workloads
- `openebs-hostpath` — local node storage (CNPG, logs, actions-runner)
- `nfs-media` — external NFS for media library

## Reference Docs

**Read [`CONTEXT.md`](CONTEXT.md) first.** It is the map: the glossary, the routing table for `docs/context/` (state), and the index of `docs/adr/` (decisions).

Two rules it enforces:

- Read the `docs/context/` file covering the area before touching code — don't grep READMEs.
- Read the ADRs touching that area too. Don't re-litigate a recorded decision; supersede it if it's wrong.

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
- **Kopiur**: Restore by editing the `Restore` CR's `spec.offset` in the app namespace (0 = latest snapshot).
- **`flate` fails with `basic credential not found`**: charts served by the private `ocharted` proxy (`oci://ocharted.${SECRET_DOMAIN}/…`) need OCI auth. The OCIRepositories carry no `secretRef` on purpose — ocharted's `auth.bypassNetworks` exempts in-cluster Flux, but a workstation is outside that CIDR. Fix: `just kube registry-auth`, which pulls `/kubernetes/ocharted` from aKeyless into `~/.config/flate/registry.json` (`FLATE_REGISTRY_CONFIG`, set in `.mise.toml`). Not a manifest bug — never "fix" it by editing the OCIRepositories.
