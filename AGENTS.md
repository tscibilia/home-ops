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

**Skill catalog** — `.agents/skills/`, one `SKILL.md` per directory:

| Skill                 | Use when                                   |
| --------------------- | ------------------------------------------ |
| `add-app`             | Adding a new application to the cluster    |
| `karpathy-guidelines` | Full text of the four standing rules above |
| `pr-review`           | Reviewing a PR or local diff before merge  |

**Memory** — this repo uses memini (MCP) for cross-session memory: decisions and
their reasons, root causes, conventions, environment quirks. Consult it before
work that may have history. Harnesses without memini should treat `CONTEXT.md`,
`docs/context/` and `docs/adr/` as the authoritative substitute — memory is a
convenience layer over those, never the only home for a fact.

**Safety tiers:**

- **Always:** read-only inspection, local validation, formatting, linting
  (`flate test all`, `flate build`, `just docs test`).
- **Ask first:** any git push the Commit Protocol below does not cover, anything
  that touches the live cluster — `just kube apply-ks`, `just kube sync`,
  `just kube reconcile-ks`, `just kube reconcile-hr`, `just kube restart-ks`,
  `just kube restart-hr`, `flux reconcile`, `talos apply` — deleting resources.
- **Never:** push to `main`, merge a PR, commit secrets, decode or print
  Kubernetes secret values, edit existing ADRs in `docs/adr/` — supersede them
  instead; adding a new ADR is fine.

## Task Runner & Workflow

`just` modules: `bootstrap`, `kube`, `talos`, `ansible`, `docs`. Using `just <module-name>` will list available commands.

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
3. Commits and PRs: follow the Commit Protocol below
4. Docs: update the affected `docs/context/` file(s) in the same change. If the change involved a decision — a trade-off with real alternatives that's costly to reverse — add an ADR instead of writing the rationale into a context file.
5. Generated docs: adding, removing or renaming an app or a docker stack changes a generated section. Run `just docs generate`. `just docs test` runs both gates — the generated sections and the identifiers — and lefthook runs it pre-commit.

## Architecture & Structure

**Monorepo Layout:**

```text
CONTEXT.md                    # Map: glossary · state routing · ADR index — read first
docker/                       # Server configs (unraid, truenas, vps)
docs/                         # context/ (state) · adr/ (decisions) · agents/ (skill config) · scripts/ (doc generators) · WORKLOG.md
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
- `nfs-share` — external NFS (csi-driver-nfs) for shared storage; the media library is mounted as a direct `type: nfs` volume, not via a class

## Reference Docs

**Read [`CONTEXT.md`](CONTEXT.md) first.** It is the map: the glossary, the routing table for `docs/context/` (state), and the index of `docs/adr/` (decisions).

Two rules it enforces:

- Read the `docs/context/` file covering the area before touching code — don't grep READMEs.
- Read the ADRs touching that area too. Don't re-litigate a recorded decision; supersede it if it's wrong.

## Commit Protocol

**`main` moves only through a PR the user reviewed.** Both paths below are review.

Either path first: YAML schema-validated, linted, formatted; `just docs generate`
if an app or docker stack was added, removed or renamed.

- **Local harness** — shares the user's machine and signing key: hand over a
  formatted commit message and stop.
- **Remote harness** — own checkout, credentials and signing key (hermes): commit
  on a feature branch, push it, open the PR, report the URL.

## Tooling Quirks

- **Bash cwd resets per call**: The working directory resets between every invocation. Never assume `cd` persisted — use absolute paths.
- **Read tracks files by absolute path**: The same file read from the repo root and from a worktree are two different tracked entries. Re-read after switching contexts.

## Troubleshooting

- **Flux/GitOps**: `kubectl edit` is ephemeral; always use `git`. Check failures: `mise && kubectl get ks -A | grep -v True`.
- **Talos**: No SSH. Use `talosctl`. Edit templates in `kubernetes/talos/`, then `just talos apply-node <node>`.
- **Cilium**: eBPF replacement for kube-proxy. Use `cilium` CLI for network debugging.
- **CNPG**: Use `-rw` endpoint for app connections. Check health: `kubectl get cluster -n database`.
- **Kopiur**: Restore by editing the `Restore` CR's `spec.offset` in the app namespace (0 = latest snapshot).
- **`flate` fails with `basic credential not found`**: charts served by the private `ocharted` proxy (`oci://ocharted.${SECRET_DOMAIN}/…`) need OCI auth. The OCIRepositories carry no `secretRef` on purpose — ocharted's `auth.bypassNetworks` exempts in-cluster Flux, but a workstation is outside that CIDR. Fix: `just kube registry-auth`, which pulls `/kubernetes/ocharted` from aKeyless into `~/.config/flate/registry.json` (`FLATE_REGISTRY_CONFIG`, set in `.mise.toml`). Not a manifest bug — never "fix" it by editing the OCIRepositories.
