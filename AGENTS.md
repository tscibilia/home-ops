# Project Overview

Home-ops monorepo. K8s cluster (Talos + Flux CD + Helm/Kustomize) on 3 bare-metal controlplane nodes with Rook Ceph.
**Instructions:** This file is the canonical, agent-independent source of repository policy. Essential rules live here directly or linked to another document; do not rely on agent-specific import syntax to load them.

## Standing Rules

**Karpathy guidelines govern every change** — full text `.agents/skills/karpathy-guidelines/SKILL.md`:

1. **Think before coding**: state assumptions; if unclear, stop and ask; don't pick silently between readings.
2. **Simplicity first**: minimum code that solves it; nothing speculative.
3. **Surgical changes**: touch only what you must; no adjacent cleanup; match existing style.
4. **Goal-driven**: state plan as `[step] → verify: [check]`; every changed line traces to the request.
5. **Report concisely**; sacrifice grammar for the sake of concision.

## Repository map

- `kubernetes/apps/<namespace>/<app>/`: application Flux Kustomizations, HelmReleases, chart sources, and configuration.
- `kubernetes/flux/cluster/`: Flux entry point and cluster-wide application patches.
- `kubernetes/components/`: reusable Kustomize components, including namespaces, CloudNativePG, and backups.
- `kubernetes/talos/`: Talos templates, node overrides, version declarations, and operational recipes.
- `kubernetes/bootstrap/`: cluster bootstrap configuration and recipes.
- `docker/` and `ansible/`: Docker-host applications and host provisioning.
- `.github/workflows/`: CI and AI PR review; `.renovate/`: dependency-update presets.
- `.mise.toml`: tool versions and environment; `.justfile` and `mod.just` files: operational commands.

## Repository conventions

- This repository manages live infrastructure through GitOps. Flux will reconcile changes under `kubernetes/` soon after merge. Consider rendered resources and deployment impact, not only the source diff.
- Follow existing neighboring applications rather than assuming a shared-base or multi-cluster overlay layout; each app is a self-contained `app/` directory plus a `ks.yaml` entry point.
- `metadata.namespace` is intentionally omitted on application HelmReleases and Flux Kustomizations. Namespace kustomizations at `kubernetes/apps/<namespace>/kustomization.yaml` set the namespace of the Flux Kustomizations; each application's Flux Kustomization sets `spec.targetNamespace` for its deployed resources. Do not add redundant namespaces or flag their absence without checking that chain.
- Prefer immutable `@sha256:` digests for container images. OCI Helm chart sources use `OCIRepository.spec.ref.tag` or a version selector; do not apply the container-image digest convention to chart references.
- For dependency reviews, verify upstream changes using available read-only release notes, changelogs, source comparisons, or image metadata. Helm chart and container-image reviews require upstream evidence, not only Renovate's description. Report unavailable evidence as unverified; never invent tool results or compatibility claims.
- When editing YAML, read `docs/agents/sorting-instructions.md` and preserve its Kubernetes and app-template ordering conventions. Avoid unrelated sorting churn, and do not reorder configuration embedded in string fields.
- Application workloads normally use Flux HelmReleases with `spec.chartRef` pointing to a per-app `OCIRepository` in `ocirepository.yaml`. Follow `.agents/skills/add-app/SKILL.md` for scaffolding; existing raw manifests and operator-managed resources are not automatically violations.
- Keep component-specific documentation alongside its configuration. Do not copy another home-ops repository's paths, architecture, or operational commands without checking this tree.
- This repo uses memini for cross-session memory: decisions and their reasons, root causes, conventions, environment quirks. Consult it before work that may have history. One-time setup: `/memini:namespace tscibilia/home-ops` pins the namespace server-side. Harnesses without memini should treat `CONTEXT.md`, `docs/context/` and `docs/adr/` as the authoritative substitute. Memini is a convenience layer, never the only home for a fact.

## Working in this repo

- The **`main`** branch moves only through a PR reviewed by the human-in-the-loop.
    1. **Local harness** — shares the user's machine and signing key: hand over a formatted commit message and stop.
    2. **Remote harness** — own checkout, credentials and signing key (hermes): commit on a feature branch, push it, open the PR, report the URL.
- PR titles follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[(scope)][!]: <description>`. Individual commit messages don't have
  to follow the format, though matching it is fine. Sign off commits: `git commit -s`.
- Commit and create PRs with `git` and `gh` directly, not an agent's eval-based commit helper: the helper builds through `commit-tree`, so its commits are unsigned, and this repo's `.omp/config.yml` pre-approves `git` and `gh pr create`. The host-level `~/.omp/agent/RULES.md` states the same rule.
- **Never** `git commit`, `git push`, or open a PR unless asked to. Ask before any destructive or hard-to-reverse action instead of defaulting to it.
- After a change, actually run the affected app's test (see "Validation" below) before calling it done, and check `.github/workflows/` for what CI actually enforces beyond that rather than assuming.
- Cross-repo references are Markdown links to `https://redirect.github.com/<owner>/<repo>/issues/<N>` (or `/pull/<N>`), display text `owner/repo#N`. Never bare `github.com` URLs or bare `owner/repo#N`; the latter creates a public `cross-referenced` event in the upstream issue. Same-repo `#N` is fine. See `docs/agents/issue-tracker.md`.
- Comments should be used sparingly, and two lines maximum. State one non-obvious fact (why, constraint, hazard); never narrate the code, restate a name, record a change, or leave commented-out code. If it needs a third line, fix the code or the abstraction.

## Operational safety

- **Always:** read-only inspection, local validation, formatting, linting (`flate test all`, `flate build`, `just docs test`).
- **Never:** push to `main`, merge a PR, commit resolved secrets, commit plaintext credentials, edit existing ADRs in `docs/adr/` — supersede them instead; adding a new ADR is fine.
- **Never:** decode, decrypt, unseal, or print any secret, credential value, kubeconfigs, or Talos client configuration from Talos, Kubernetes, aKeyless, ESO, SOPS, cloud providers, CI, or any other store. Kubernetes application secrets normally come from External Secrets backed by aKeyless; keep secret values out of inline Helm values and session context. If a value reaches output, say so in the same turn and rotate at the source; never inspect it further (see "Secret Handling" below).
- Talos templates intentionally contain `ak://` references resolved at runtime through `kubernetes/bootstrap/scripts/akeyless-inject.sh`. Docker-host and Ansible workflows also use aKeyless; follow their existing mechanisms rather than requiring Kubernetes External Secrets outside Kubernetes.
- Local template rendering might resolve real credentials. Do not include resolved output in logs, responses, or committed files.
- Treat persistent-volume changes, CloudNativePG bootstrap/recovery and object-store settings, backup policies, resource renames, and Flux `prune`/`suspend` changes as potential data-loss or availability risks. Inspect affected consumers and rendered changes before recommending them.
- CloudNativePG components live under `kubernetes/components/cnpg/`. Read the existing cluster configuration and `just bootstrap cnpg` recipe before changing bootstrap behavior; do not replace recovery with `initdb` as a generic fix.
- Repository edits do not authorize live infrastructure changes. Do not apply, reconcile, upgrade, delete, reset, or seed infrastructure unless the user explicitly requests that operation.

## Where To Look

- Start in `docs/context/`: read the file for the area before touching code or debugging a failure — `CONTEXT.md` routes each area to its file, and most files open with `⚠️ Gotchas & Interactions`. Don't grep READMEs. Read the ADRs touching it too; don't re-litigate a recorded decision, supersede it if it's wrong.
    1. **Domain docs**: [`CONTEXT.md`](CONTEXT.md) is the map (glossary, state routing, ADR index). `docs/context/` = state, `docs/adr/` = decisions. See `docs/agents/domain.md`.
    2. **Issue tracker**: GitHub Issues on `tscibilia/home-ops`, via `gh`. See [`issue-tracker.md`](docs/agents/issue-tracker.md).
    3. **Triage labels**: five canonical roles, default label strings. See [`triage-labels.md`](docs/agents/triage-labels.md).
    4. **PR review**: CI reviewer prompt and judgement rules in [`pr-review-instructions.md`](docs/agents/pr-review-instructions.md); the `pr-review` skill adds the evidence-gathering workflow.
- For sub-directory specifics not covered by `docs/context/`, read that directory's `README.md`, e.g. `kubernetes/bootstrap/cnpg/README.md`.
- Skill catalog exists in `.agents/skills/`, enumerated by one `SKILL.md` per directory (Read the matching skill before performing these tasks).

## Secret Handling

- Per store: **metadata projection first; never retrieve; redact only inside the producing pipe.** Truncation (`head`, `cut`) is not redaction. App data and databases are a gate: schema first, columns by name, never `SELECT *`.
- Safe and forbidden commands per store (Kubernetes, aKeyless, SOPS, Talos, cloud managers, SQLite/Postgres, PVCs, env, logs): [`docs/context/secrets.md`](docs/context/secrets.md).

## Validation

- Use the repository's mise-managed tools and inspect with `just <module-name>` (available modules: `bootstrap`, `kube`, `talos`, `ansible`, `docs`) to list available commands.
- Update relevant `docs/context/*` file(s) in the same change. If the change involved a decision — a trade-off with real alternatives that's costly to reverse — add an ADR instead of writing the rationale into a context file.
- When adding, removing or renaming an app or a docker stack changes a generated section in `docs/*`. Run `just docs generate`. `just docs test` runs both gates — the generated sections and the identifiers — and lefthook runs it pre-commit.
- For Kubernetes manifest changes: `just kube registry-auth` — one-time per machine; required before the first `flate` run. If `flate` reports `basic credential not found`, that is the cause: the private `ocharted` proxy exempts in-cluster Flux via `auth.bypassNetworks`, not a workstation. Never "fix" it by adding `secretRef` to the OCIRepositories.
- Then inspect the rendered impact when tools and network access permit:

```sh
flate test all --path ./kubernetes/flux/cluster
flate diff all --path ./kubernetes/flux/cluster --base origin/main
```

_These commands may fetch upstream sources. They do not replace checking CRDs, secrets, or runtime behavior omitted from rendered output. For documentation-only changes, targeted reference and whitespace checks are sufficient. Report which checks ran and any validation gaps; do not claim an unavailable render or test passed._

## Instruction ownership

- Keep shared policy in this file, task workflows in `.agents/skills/`, and detailed conditional guidance in `docs/agents/`. Do not duplicate policy in task files.
- `CLAUDE.md` is an import shim for `AGENTS.md`; `.claude/skills` symlinks `.agents/skills`. Keep agent-specific directories limited to adapters and configuration, not alternative copies of shared guidance.
- Keep personal model preferences, credentials, permissions, and MCP configuration in user-level configuration, synchronized through dotfiles or another user-configuration mechanism when needed across machines.
