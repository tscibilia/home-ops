# The Hermes agent opens pull requests and cannot land them

**Status:** accepted
**Date:** 2026-08-16

The agent has a shell, `gh`, and a fine-grained PAT carrying read/write on code, issues and pull requests. It may clone, branch, commit and open a pull request. It may not put anything on a default branch. Enforcement is a GitHub ruleset per repository — server-side refusal, not agent configuration.

## Considered options

**The agent's own `approvals.deny` globs.** `approvals.deny` matches fnmatch patterns before the yolo bypass and carries entries for `git push*origin main*`, force-push, `gh pr merge*` and `gh repo delete*`. Kept, but not relied on: a bare `git push` from a branch with an upstream never matches any of them, and the whole mechanism is configuration the agent's own tooling chooses to honour rather than something the far end refuses.

**A bypass for Repository admin, so the operator keeps direct pushes.** Rejected. The agent authenticates with the operator's PAT, so to GitHub it is the same actor holding the same role; a bypass granted to the human is inherited by the agent and the ruleset stops meaning anything. The cost is real and was paid deliberately — 18 of the 50 commits preceding this change went straight to `main`.

**A separate machine account for the agent.** The only arrangement that gives both halves: the agent added as a write-level collaborator, the operator bypassing as admin. Deferred, not rejected. It needs a second GitHub account, collaborator invites per repo, its own PAT and signing key, and a matching `GIT_AUTHOR_EMAIL`.

## Consequences

- Rulesets are per repository. Organisation-wide rulesets exist only for organisations and `tscibilia` is a personal account, so each repo carries its own copy with an **empty bypass list** and `~DEFAULT_BRANCH` as the only condition. None of this lives in git; the GitHub console and this ADR are the whole record.
- Applied to `home-ops`, `akeyless-proxy`, `greenlight` and `linkcard`: `deletion`, `required_signatures`, `non_fast_forward`, `pull_request` with **0 required approvals**. Requiring one would deadlock a single-maintainer repo, because GitHub forbids approving your own pull request.
- `home-ops` additionally requires the `Image Pull - Success` check. That rule is deliberately **not** copied to the others — a required check that no workflow emits leaves every pull request unmergeable forever.
- `ce-transcript` is unprotected and cannot be fixed. Rulesets on private repositories need a paid plan. The mitigation is to narrow the PAT to selected repositories and leave it out, so the agent cannot reach the one repo that cannot be defended.
- `required_signatures` forces commit signing on the agent. Its commits are SSH-signed with a key delivered from aKeyless as `GH_HERMES_SIGNING_KEY`, written to `/opt/data/.ssh/hermes_signing` at 0600 by `02-init-config` — `ssh-keygen` refuses a group- or world-readable key, so the mode is load-bearing. Git is configured through `GIT_CONFIG_COUNT`/`KEY`/`VALUE` rather than a `.gitconfig`, matching how the commit identity is already supplied to a PVC that has none.
- The agent commits as `hermes <585808+tscibilia@users.noreply.github.com>`. A signature renders **Unverified** unless the author email is a verified address on the account holding the key, so the agent's own noreply address will not serve. The consequence is that its commits are indistinguishable from the operator's in the audit trail — the strongest argument for the deferred machine account.
- Rebase merging is disabled repository-wide. GitHub adds rebased commits to the base branch without signature verification and cannot sign them on the author's behalf, so rebase and `required_signatures` are incompatible. Merge commits and squash remain; squash takes the pull request title and body.
