````markdown
# Phase prompts

Each phase is self-contained: give it only its own prompt, never the whole
`SKILL.md`. Replace `${PR_ID}` and the file list. Run in parallel where the harness
supports it; the phases share no state.

Output path for every phase: `.agents/pr-review/pr-${PR_ID}/`

## Phase 1 — Rendered-manifest diff

```text
Determine the real cluster impact of this change by diffing rendered manifests,
not the git diff.

Repo: home-ops (Talos + Flux + Helm/Kustomize). Renderer: flate (konflate).

TASKS
1. Identify the merge-base:
     git merge-base HEAD origin/main
2. Render both sides to separate trees:
     git stash list  # note any local state before switching
     mise exec -- flate build all > /tmp/pr-${PR_ID}-head.yaml
     git checkout <merge-base> -- kubernetes/
     mise exec -- flate build all > /tmp/pr-${PR_ID}-base.yaml
     git checkout HEAD -- kubernetes/
   If `flate build all` fails with "basic credential not found", run
   `just kube registry-auth` first — private ocharted charts need OCI auth from a
   workstation. That is not a manifest bug; never "fix" it by editing OCIRepositories.
3. Diff base vs head. Report every changed resource, not just the obviously
   related ones.
4. Flag specifically — these are the failures release notes omit:
   - renamed or removed Helm values keys (a value silently stops applying)
   - changed securityContext runAsUser/fsGroup (existing PVC data becomes unreadable)
   - changed probe paths, ports, or thresholds
   - added or removed CRD fields
   - changed volume mounts, subPaths, or storage classes
   - resources that disappear entirely between base and head
5. Note whether the change is confined to image tags and digests. If so, say so
   plainly — that is the routine case and deserves a short report.

OUTPUT to .agents/pr-review/pr-${PR_ID}/phase-1-rendered-diff.md:

# Phase 1: Rendered diff
**Completed:** [timestamp]
## Blast radius
N added · N changed · N removed
## Findings
| Severity | Resource | Field | Base → Head | Why it matters |
|----------|----------|-------|-------------|----------------|
## Summary
One paragraph: is the rendered change what the git diff implied?
```

## Phase 2 — Upstream breaking changes

```text
Research upstream breaking changes for this PR.

Follow the method in .agents/skills/pr-review/references/upstream-research.md
exactly, including its budget order. Read that file first.

TASKS
1. Identify what is upgraded and whether it wraps another component.
2. Research the full version span for both wrapper and inner component.
3. Map each finding onto what this repo actually consumes — grep kubernetes/ for
   the changed surface before calling anything actionable.
4. State explicitly what you could not find. Never fabricate a changelog.

OUTPUT to .agents/pr-review/pr-${PR_ID}/phase-2-upstream.md:

# Phase 2: Upstream
**Completed:** [timestamp]
## Chain
| Layer | Component | Old | New |
|-------|-----------|-----|-----|
## Findings
| Severity | Change | Affects this repo? | Detail |
|----------|--------|--------------------|--------|
## Not found
What you looked for and could not locate.
## Sources
```

## Phase 3 — Conventions and ADRs

```text
Check this PR against home-ops conventions.

READ FIRST: CONTEXT.md (the map), then the docs/context/ file its routing table
names for the areas this PR touches, then any ADR in docs/adr/ covering them.
ADR-0002 governs Flux repository conventions and ks.yaml structure.

TASKS
1. Structure: kubernetes/apps/{namespace}/{app}/ with ks.yaml + app/.
2. ks.yaml: dependsOn, postBuild.substitute, components, targetNamespace — per ADR-0002.
3. Components in the right place: app components (auth, cnpg, kopiur/backup,
   zeroscaler) in ks.yaml spec.components; namespace components (alerts, secrets,
   kopiur/secret) in kubernetes/apps/{ns}/kustomization.yaml. These are never
   interchangeable.
4. Naming: lowercase-dashes resources, kebab-case files, ks.yaml name matches dir.
5. YAML anchors for repeated values, anchored on first real usage — never a
   junk anchor-only key.
6. Generated docs: if an app or docker stack was added, removed or renamed,
   `just docs generate` must have been run.

DO NOT REPORT (documented as intentional):
- absent metadata.namespace on HelmRelease/Kustomization — injected by kustomize
- OCI artifacts pinned by tag rather than @sha256: — that policy is images only

OUTPUT to .agents/pr-review/pr-${PR_ID}/phase-3-conventions.md with a
| Severity | File | Convention | Detail | table, and a line naming which
docs/context/ files and ADRs you actually read.
```

## Phase 4 — Secrets and exposure

```text
Review secrets handling and network exposure.

This repo uses External Secrets Operator against aKeyless. It does NOT use SOPS —
do not look for sops: keys or age recipients.

TASKS
1. Every ExternalSecret: does its aKeyless remoteRef path follow the convention in
   docs/context/secrets.md? Cross-check against a peer app.
2. No plaintext credentials, tokens, or keys anywhere in the diff.
3. No hardcoded domains — ${SECRET_DOMAIN} via postBuild substitution.
4. HTTPRoute parentRef: envoy-internal is LAN; envoy-external is internet-reachable.
   Flag every new or changed envoy-external route and ask whether the exposure is
   deliberate. This is the highest-consequence check in the phase.
5. Auth: an app with built-in auth must NOT also get the auth component. Native
   OIDC (PocketIDOIDCClient) and forward auth (auth component) are alternatives,
   never companions.
6. securityContext: flag containers newly running as root.

NEVER decode or print secret values. List key names only.

OUTPUT to .agents/pr-review/pr-${PR_ID}/phase-4-secrets-exposure.md with a
| Severity | File | Issue | Detail | table.
```

## Phase 5 — Build validation

```text
Run build validation for this PR.

TASKS
1. Run: bash .agents/skills/pr-review/scripts/validate-pr.sh
2. If flate fails with "basic credential not found", run `just kube registry-auth`
   once, then re-run. That is workstation OCI auth, not a manifest bug.
3. Report every failure with the file and the renderer's own message. Do not
   paraphrase an error — quote it.
4. Run `just docs test` and report both gates (generated sections, identifiers).

Do NOT run `just kube apply-ks` or any other command that touches the live
cluster. This phase is read-only.

OUTPUT to .agents/pr-review/pr-${PR_ID}/phase-5-validation.md:

# Phase 5: Validation
**Completed:** [timestamp]
| Check | Result | Detail |
|-------|--------|--------|
| flate test all | pass/fail | |
| shellcheck | pass/fail/n-a | |
| just docs test | pass/fail | |
## Failures
Quoted output, one block per failure.
```
````
