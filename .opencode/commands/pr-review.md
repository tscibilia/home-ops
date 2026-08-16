---
description: Five-phase GitOps review of a PR or the local diff
subtask: true
---

# PR review

@.agents/skills/pr-review/SKILL.md

Follow the skill above exactly. Target: $ARGUMENTS

Resolve the target like this:

- a bare number (`3331`) → `PR_ID=3331`, review that PR
- `local`, `local-changes`, or no argument → `PR_ID=local-changes`, review the
  staged **and** unstaged diff
- "will this bump break anything" → phases 1 and 2 only
- "validate before I push" → phase 5 only

Working tree as of invocation:

!`git status --short; echo "--- diff vs HEAD ---"; git --no-pager diff HEAD --stat | tail -30`

Before you judge anything, read `.agents/pr-review-instructions.md`. It is
authoritative for the severity vocabulary and for when to escalate rather than
dismiss a finding; this skill only governs how to _gather_ evidence.

Respect the hard boundaries:

- **Local only.** Never post a comment, submit a review, approve, label, or edit
  the PR. No `gh pr review`, no `gh pr comment`, no `gh api` writes. CI owns
  everything published to GitHub.
- **Read-only** on the repo and the cluster — no edits to tracked files, no
  commits, nothing that mutates cluster state.
- **Never read unbounded output into context.** Redirect to a file, check its
  size, then extract only what you cite. A full render is ~118,000 lines and will
  kill the phase. A phase that reports its own gaps is useful; one that dies
  mid-fetch is not.

Finish with the severity table (`blocker` / `major` / `minor` / `info`, blockers
first) and the path to the aggregate under `.agents/pr-review/pr-<id>/`.
