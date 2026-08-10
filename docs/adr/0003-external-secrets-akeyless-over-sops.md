# External Secrets Operator with aKeyless, replacing SOPS

**Status:** accepted
**Date:** 2025-04-06
**Supersedes:** ADR-0001 (SOPS + age)

The upstream template encrypts secrets into git with SOPS + age, which means every secret rotation is a commit and every consumer needs the age key. External Secrets Operator was adopted instead, backed by aKeyless as the remote store, so secrets live outside the repo entirely and rotate without a commit.

## Considered options

Bitwarden Secrets Manager was tried first (2025-04-01) and abandoned two days later (2025-04-02) — it is recorded here only so the two-day gap in git history isn't mistaken for a real deployment. aKeyless landed 2025-04-06 and has backed every secret since.

## Consequences

- Nothing in the repo is encrypted; the repo carries no secret material at all, only `ExternalSecret` references.
- A wrong aKeyless path yields a **silent empty secret** with no error logged — the most common secret failure in this cluster.
- SOPS removal took until 2026-01-07 (`3ed462a44`) to complete; commits before that date may still reference it.
- pocket-id inverts the flow: it _generates_ credentials, so those are pushed to aKeyless with a `PushSecret` rather than read with an `ExternalSecret`. See ADR-0014.
