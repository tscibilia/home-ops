---
name: pr-review
description: >-
    Review a GitOps Kubernetes PR or local diff in this repo: rendered-manifest
    impact, upstream breaking changes, repo conventions and ADRs, secrets and
    exposure, and build validation.

    user: "Review PR 3331" → five phases, aggregated under .agents/pr-review/pr-3331/
    user: "Will this bump break anything?" → phases 1 and 2
    user: "Review my local changes" → PR_ID=local-changes, staged + unstaged diff
    user: "Validate before I push" → phase 5

    Use for Renovate bumps, new apps, component or Flux changes, and pre-commit review.
compatibility: >-
    Requires git and flate (via mise). Optional: gh for PR metadata, shellcheck for
    phase 5. Works in any harness that reads SKILL.md; parallel phases are a
    performance optimisation, not a requirement.
---

# PR review

Five focused phases over a PR or local diff. Each phase is independent and writes
its own report, so they can run in parallel or one after another.

## Hard boundaries

**This review is local. Never publish it.** Do not post a comment, submit a
review, approve, request changes, apply a label, or edit the PR body or title.
No `gh pr review`, no `gh pr comment`, no `gh api` write of any kind. A separate
CI reviewer owns everything published to GitHub; a second voice posting there is
noise at best and a contradictory verdict at worst. Your output is the files
under `.agents/pr-review/pr-<id>/` plus what you say to the person who asked.

**Read-only on the repository and the cluster.** Do not edit tracked files, do
not commit, and run nothing that mutates cluster state.

**Never read unbounded output into your context.** This is the rule that decides
whether a review finishes. A full cluster render is ~118,000 lines and a GitHub
releases page is hundreds of KB of markup — a couple of those and the phase dies
in a compaction loop with nothing written. Always: redirect to a file, check its
size, then extract only what you cite (`wc`, `grep -c`, scoped `grep`, `--jq`).
Prefer an API returning a single field over a page you must parse. If context
runs short, write the report you can support and list the rest under "Not found"
— a phase that reports its own gaps is useful, one that dies mid-fetch is not.

**Judgement rules live in
[`.agents/pr-review-instructions.md`](../../pr-review-instructions.md).** Read it
before reaching a recommendation. It is authoritative for the severity
vocabulary, for when to escalate a finding rather than dismiss it, and for the
rule that an unverified upgrade mechanism cannot be approved. This skill governs
_how to gather_ evidence; that file governs _how to judge_ it.

## Why this exists

Release notes are not a reliable breaking-change signal. A chart can rename a
values key, change a default UID, or drop a CRD field and ship it under "chores".
Phase 1 catches that class by diffing the _rendered_ manifests rather than the git
diff — it is the phase to run when nothing else looks wrong.

## Repository context

Read `CONTEXT.md` first — it is the map (glossary, `docs/context/` routing table,
ADR index). Do not grep READMEs.

- Layout: `kubernetes/apps/{namespace}/{app}/` with `ks.yaml` + `app/`
- Charts: mostly `bjw-s/app-template`; private charts via `oci://ocharted.${SECRET_DOMAIN}`
- Secrets: External Secrets Operator against aKeyless. **Not SOPS.**
- Routes: Gateway API `HTTPRoute`, parentRef `envoy-internal` (LAN) or
  `envoy-external` (internet-reachable — external exposure must be deliberate)
- Validation: `mise exec -- flate test all`
- Memory: this repo uses memini (MCP) for prior decisions and root causes. Consult
  it for history on an unfamiliar area. Without it, `docs/context/` and `docs/adr/`
  are the authoritative substitute.

## Workflow

1. **Initialize** — set `PR_ID` from the PR number (`3331`) or `local-changes`.
2. **Prepare** — `mkdir -p .agents/pr-review/pr-${PR_ID}`; for local reviews capture
   the diffs first (see [references/workflow.md](references/workflow.md)).
3. **Run phases 1–5** — in parallel if the harness supports it, otherwise in order.
   Prompts: [references/phase-prompts.md](references/phase-prompts.md).
4. **Aggregate** — merge into `pr-review-state.md` (template in
   [references/workflow.md](references/workflow.md)).
5. **Present** — severity table, blockers first, then the aggregate path.

## Phase map

| Phase | Focus                                   | Output file                   |
| ----- | --------------------------------------- | ----------------------------- |
| 1     | Rendered-manifest diff (cluster impact) | `phase-1-rendered-diff.md`    |
| 2     | Upstream breaking changes               | `phase-2-upstream.md`         |
| 3     | Conventions and ADRs                    | `phase-3-conventions.md`      |
| 4     | Secrets and exposure                    | `phase-4-secrets-exposure.md` |
| 5     | Build validation                        | `phase-5-validation.md`       |

Formatting (indentation, trailing whitespace, line endings) is deliberately not a
phase — lefthook and prettier already enforce it pre-commit, so a phase could only
add noise or false confidence.

## Severity vocabulary

Use exactly `blocker`, `major`, `minor`, `info` — the same words the CI reviewer
uses, so findings from both paths are comparable.

## Inline quick checklist

For a one-file diff, skip the phases and check:

- [ ] `flate test all` passes
- [ ] Rendered diff shows only what you intended
- [ ] `ks.yaml` structure and `dependsOn` match ADR-0002
- [ ] ExternalSecret aKeyless path exists; no plaintext credentials
- [ ] `envoy-external` only where internet exposure is deliberate
- [ ] Affected `docs/context/` file updated

## Progressive disclosure

- Phase prompts: [references/phase-prompts.md](references/phase-prompts.md)
- Init, local diff, aggregation: [references/workflow.md](references/workflow.md)
- Upstream research method: [references/upstream-research.md](references/upstream-research.md)
- Validation script: [scripts/validate-pr.sh](scripts/validate-pr.sh)
