# aKeyless GitHub Action for CI secrets, replacing GitHub repository secrets

**Status:** accepted
**Date:** 2026-08-13
**Extends:** ADR-0003 (aKeyless to include GitHub Actions)

ADR-0003 moved cluster secrets to aKeyless but left CI behind: workflows kept their own copies as GitHub repository secrets, so credentials existed in two places and rotation meant updating both. Workflows now fetch from aKeyless at run time with `akeyless-community/akeyless-github-action`, authenticating with the GitHub OIDC token. No long-lived aKeyless credential is stored in GitHub, and `secrets.GITHUB_TOKEN` — injected per job, not stored — is the only `secrets.*` reference left in any workflow.

## Considered options

No alternatives considered — aKeyless was already the store (ADR-0003), and the only question was how workflows reach it. `akeyless-community/akeyless-github-action` is Akeyless's own action; its docs cover no other. onedr0p's `renovate.yaml` supplied the step shape, which he implements with 1Password's `load-secrets-action`.

aKeyless supports `access-type: access_key` as well as `jwt`. Access-key auth needs a long-lived `AKEYLESS_ACCESS_KEY` in GitHub, which reduces the change to swapping which secrets are stored rather than removing them. JWT/OIDC was chosen for that reason; access-key remains the fallback if the auth method breaks.

`release.yaml` held a classic PAT (`PAT_WORKFLOW`) so releases could trigger downstream workflows — a capability `GITHUB_TOKEN` lacks. Nothing in this repo triggers on `release`, so it was replaced with a Kube Skywalker app token minted per run.

## Consequences

- Auth method `gh-actions` (oauth2/jwt) is bound to role `/github` by sub-claim `repository=tscibilia/home-ops`. None of this lives in git — the console is the only record besides this ADR.
- **Audience URL must stay empty.** The action calls `core.getIDToken()` with no argument, so GitHub mints the token with the account default audience, never `akeyless.io`. Setting Audience — as the Akeyless GCP example shows — breaks every login. Issuer is optional; if set it must be exactly `https://token.actions.githubusercontent.com`.
- The Access ID is a repo **variable** (`vars.AKEYLESS_ACCESS_ID`), not a secret: it names an auth method rather than granting anything. `vars.` and `secrets.` are separate namespaces — a value in the wrong one resolves to an **empty string with no error**, the same silent-empty failure ADR-0003 records for wrong aKeyless paths.
