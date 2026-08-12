# Upstream research method

> **Read [`.agents/pr-review-instructions.md`](../../../pr-review-instructions.md)
> first — it is authoritative.** That file is the CI reviewer's prompt and the
> single source of truth for this repo's review judgement: the severity
> vocabulary, the impact-assessment rules (when to escalate a finding, not only
> when to dismiss one), the prohibition on asserting an unverified upgrade
> mechanism, and the repo conventions that must never be reported as problems.
>
> This file adds only the breadcrumb-following method below. Where the two
> appear to differ, that file wins. Do not restate its rules here — an earlier
> duplicate of them drifted out of sync and produced a wrong `Approve` on a
> PostgreSQL major-version upgrade.

Changelogs live at the source, not at the wrapper. A Docker image bump from v1.2 to
v1.3 might re-wrap an upstream tool that jumped 4.0 → 5.0; the meaningful changelog
is the upstream one.

## Identify the chain

1. What is being upgraded — container image, Helm chart, tool, GitHub Action.
2. Whether it is a wrapper bundling another component. If so, identify the inner
   component and _its_ version change too. Review both.

## Follow breadcrumbs, in budget order

Steps 1–3 are mandatory. Stop where your budget ends and say so.

1. **Rendered diff** — what actually changes in the cluster (phase 1, or
   `flate build`). This outranks every changelog because it is ground truth.
2. **Inner component and version span** — wrapper vs upstream.
3. **GitHub Releases for every version in the span**, not just the newest.
   Migration notes routinely appear only in an intermediate release.
4. **PR body** — Renovate embeds release notes; cheap to check.
5. **CHANGELOG / UPGRADING** in the repo root and `docs/`.
6. **Documentation sites** — migration guides and "what's new" pages often carry
   deprecation notices absent from changelogs.
7. **Commit history** when there is no changelog — scan messages between tags for
   `breaking`, `deprecat`, `remov`, `renam`, `migrat`, `drop`, `require`.
8. **Registry metadata** — Docker Hub, GHCR, quay.io READMEs link upstream.
9. **Web search** — last resort.

Do not stop at the first source; cross-reference. If the repo has no releases, no
changelog and no useful commit messages, say so explicitly rather than guessing.

## Assess impact against this repo

Map every finding onto what this repo actually consumes. Grep for the changed
surface. A breaking change in a feature we do not use is not actionable — say that
rather than reporting it as a risk.

## Report

Findings only: breaking changes, security holes, correctness bugs. Do not report
that expected behaviour was correct. Severities: blocker, major, minor, info.
