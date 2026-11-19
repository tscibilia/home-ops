# Owner-only merge exemption on `home-ops` main

**Status:** accepted
**Date:** 2026-11-19
**Relates to:** ADR-0019

ADR-0019 relied on an empty ruleset bypass list to stop agents landing changes. That only blocked direct pushes. With `pull_request` at zero required approvals, a write collaborator could still merge its own PR — and `obi-pod-kenobi` did.

## Decision

Add an `update` rule to the `home-ops` `Main Branch Proctection` ruleset, scoped to `~DEFAULT_BRANCH`, and exempt `tscibilia` (user 585808) from the ruleset with `bypass_mode: exempt`.

The bot keeps `Contents: write` so it can push feature branches and open PRs. It has no ruleset bypass, so it cannot update `main` by push or by merge. The owner merges normally, without a bypass checkbox.

## Alternatives rejected

- **Explicit `pull_request` bypass.** The owner sees **Merge without waiting for requirements to be met (bypass rules)** on every merge. Rejected for friction; it keeps the owner subject to the rules but adds a manual break-glass step each time.
- **Require one approval.** The bot cannot self-approve, but it can merge after the owner approves. That gates the bot on a human review, not on the owner performing the merge.
- **Remove the bot's write access and use fork PRs.** Strongest separation, but it changes every clone/push path and makes the bot's workspace a fork of each repository.
- **Leave the empty bypass list.** Rejected after the bot landed a PR.

## Consequences

- The owner is the only actor that can land a change on `home-ops` `main`.
- `exempt` skips every rule in the ruleset for the owner, not just `update`: the owner can push directly, and the owner's commits are not checked for signatures. The owner is trusted; their normal workflow already signs commits.
- The bot can still create branches, commit, and open PRs; its merge attempt is refused server-side.
- Repeat the `update` rule and owner exemption on `akeyless-proxy`, `greenlight`, and `linkcard` if the bot gets access. Do not add the bot to `ce-transcript`, which has no ruleset.
