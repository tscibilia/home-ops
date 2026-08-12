# PR review workflow

## Isolated output per review

Never use a shared output path. Each review gets its own directory:

```text
.agents/pr-review/
├── pr-3331/
│   ├── phase-1-rendered-diff.md
│   ├── phase-2-upstream.md
│   ├── phase-3-conventions.md
│   ├── phase-4-secrets-exposure.md
│   ├── phase-5-validation.md
│   └── pr-review-state.md
└── pr-local-changes/
```

Concurrent reviews, re-runs after fixes, and multiple agents then do not collide.
`.agents/pr-review/` is gitignored, so nothing here reaches a commit.

## Initialize — PR

```bash
PR_ID="3331"
mkdir -p ".agents/pr-review/pr-${PR_ID}"
gh pr view "$PR_ID" --json number,title,body,headRefName,baseRefName,files \
  > ".agents/pr-review/pr-${PR_ID}/pr-meta.json"
gh pr diff "$PR_ID" > ".agents/pr-review/pr-${PR_ID}/pr.diff"
```

## Initialize — local changes

```bash
PR_ID="local-changes"
mkdir -p ".agents/pr-review/pr-${PR_ID}"
git diff --cached --name-only > ".agents/pr-review/pr-${PR_ID}/staged-files.txt"
git diff --cached          > ".agents/pr-review/pr-${PR_ID}/staged.diff"
git diff --name-only       > ".agents/pr-review/pr-${PR_ID}/unstaged-files.txt"
git diff                   > ".agents/pr-review/pr-${PR_ID}/unstaged.diff"
git ls-files --others --exclude-standard > ".agents/pr-review/pr-${PR_ID}/untracked-files.txt"
```

Run the same five phases against these artifacts. Summarize staged, unstaged and
untracked files separately in the aggregate — an untracked file that a
`kustomization.yaml` already references is a common and easily missed break.

## Aggregation template — `pr-review-state.md`

```markdown
# PR review — pr-${PR_ID}

**Completed:** [timestamp]

## Recommendation

<Approve | Request changes> — <one clause>

| Field           | Value                                    |
| --------------- | ---------------------------------------- |
| Change          | `<artifact>` `<old>` → `<new>`           |
| Inner component | `<upstream>` `<old>` → `<new>`, or `n/a` |
| Blast radius    | `<N added · N changed · N removed>`      |
| Upstream        | <breaking changes, or "none found">      |
| Repo impact     | <what this repo consumes, or "none">     |
| Reversibility   | <how this is undone if it misbehaves>    |

## Findings

| Severity | Phase | File | Detail |
| -------- | ----- | ---- | ------ |

Omit this section when empty. Severities: blocker, major, minor, info.

## Phase reports

- .agents/pr-review/pr-${PR_ID}/phase-1-rendered-diff.md
- .agents/pr-review/pr-${PR_ID}/phase-2-upstream.md
- .agents/pr-review/pr-${PR_ID}/phase-3-conventions.md
- .agents/pr-review/pr-${PR_ID}/phase-4-secrets-exposure.md
- .agents/pr-review/pr-${PR_ID}/phase-5-validation.md
```

The recommendation table matches the CI reviewer's contract in
`.agents/pr-review-instructions.md` on purpose — the two paths should be
comparable at a glance.

## When to run fewer phases

| Situation                        | Phases  |
| -------------------------------- | ------- |
| Renovate version bump            | 1, 2    |
| New app                          | 3, 4, 5 |
| Component or Flux structure edit | 1, 3, 5 |
| Pre-push sanity check            | 5       |
| Full review                      | 1–5     |

Do not run all five on a one-file docs change. The inline checklist in `SKILL.md`
is the right tool there.

## Cleanup

Keep recent reviews for reference. `rm -rf .agents/pr-review/pr-${PR_ID}/` when done.
