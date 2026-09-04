# CONTEXT

The map for this repo: what the words mean, where the state is written down, and which decisions have been recorded.

Three kinds of documentation, split by tense:

- **`CONTEXT.md`** (this file) — vocabulary and navigation.
- **`docs/context/`** — how things are wired **now**. Updated in place as the cluster changes.
- **`docs/adr/`** — **why** a choice was made. Written once; superseded, not edited.

---

## Glossary

Use these terms exactly. They are the repo's vocabulary — synonyms drift.

| Term                                    | Meaning                                                                                                                                                                                                                                                               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **app**                                 | A directory at `kubernetes/apps/{namespace}/{app}/`. The unit of deployment. Contains `app/` and `ks.yaml`.                                                                                                                                                           |
| **ks.yaml**                             | An app's Flux `Kustomization` — its entry point. Declares `dependsOn`, `postBuild.substitute`, `components`, `targetNamespace`. Not the same file as `app/kustomization.yaml`.                                                                                        |
| **kustomization.yaml**                  | The plain Kustomize file — there are two, and they behave differently. `app/kustomization.yaml` lists an app's resources and never takes components. `kubernetes/apps/{ns}/kustomization.yaml` is the namespace index and is where namespace components are declared. |
| **component**                           | A reusable Kustomize overlay in `kubernetes/components/`. Never means "a piece of software" in this repo. Two kinds, distinguished by where they are declared — the placement is not interchangeable.                                                                 |
| **app component**                       | Declared per app in `ks.yaml` `spec.components` and configured through `postBuild.substitute`: `auth`, `cnpg`, `kopiur/backup`, `zeroscaler`.                                                                                                                         |
| **namespace component**                 | Declared once per namespace in `kubernetes/apps/{ns}/kustomization.yaml` under `components:`, with no per-app configuration: `alerts`, `secrets`, `kopiur/secret`. Never appears in a `ks.yaml`.                                                                      |
| **HelmRelease**                         | The Flux resource deploying a chart. Most apps use `bjw-s/app-template`. Distinct from the Kustomization that wraps it — `dependsOn` references the Kustomization's name, never this.                                                                                 |
| **native OIDC**                         | Auth path for apps that speak OIDC: a `PocketIDOIDCClient` CR in `app/`. No component. Preferred.                                                                                                                                                                     |
| **forward auth**                        | Auth path for apps that don't: the `auth` component, routing ext-auth to tinyauth. Mutually exclusive with native OIDC.                                                                                                                                               |
| **SecurityPolicy**                      | The Envoy Gateway CR that attaches ext-auth to an HTTPRoute — what the `auth` component actually emits. Forward auth is the concept; this is the resource.                                                                                                            |
| **envoy-internal** / **envoy-external** | The two Gateways, split by where traffic entered. `envoy-internal` serves the LAN; `envoy-external` is the only one towonel forwards to. An app is reachable from outside exactly when its HTTPRoute names `envoy-external`.                                          |
| **Gatus**                               | The health-monitoring app. `gatus-sidecar` auto-discovers every HTTPRoute — no annotation needed, except that forward-auth apps must swap route monitoring for service monitoring.                                                                                    |
| **PushSecret**                          | ESO in reverse: writes a cluster-generated value **out** to aKeyless. The opposite direction to `ExternalSecret`, which is the common case.                                                                                                                           |
| **kopiur**                              | The PVC backup/restore operator (Kopia to NFS). Restores are done by editing a `Restore` CR's `spec.offset`.                                                                                                                                                          |
| **zeroscaler**                          | The scale-to-zero component — a native HPA driven by `probe_success` through prometheus-adapter. Needs a matching prometheus-adapter ConfigMap entry or it silently never scales.                                                                                     |
| **flate**                               | The `konflate` CLI. Local rendering and validation (`flate test all`, `flate build all`). Replaced flux-local.                                                                                                                                                        |
| **cluster-secrets**                     | The Secret supplying `postBuild` substitutions (`SECRET_DOMAIN`, `TIMEZONE`, …) to every app via `substituteFrom`. Created per namespace by the `secrets` namespace component — not once cluster-wide.                                                                |
| **truenas**                             | Primary NAS. Serves the media library over NFS (mounted directly, not via a storage class) and backs the `nfs-share` class. Probe job `nfs_probe`.                                                                                                                    |
| **clonenas**                            | Backup NAS. Holds the Kopia repository and pgdumps. Probe job `nfs_bkup_probe`.                                                                                                                                                                                       |
| **ocharted**                            | The in-cluster private OCI chart proxy. Workstations need `just kube registry-auth` before the first `flate` run.                                                                                                                                                     |
| **towonel**                             | The VPS ingress path — SNI passthrough over iroh QUIC to the in-cluster `envoy-external` gateway.                                                                                                                                                                     |
| **doco-cd**                             | Pull-based GitOps for the non-Kubernetes Docker hosts (truenas, clonenas, vps).                                                                                                                                                                                       |

---

## State — `docs/context/`

**Read the relevant file before touching code.** Don't grep READMEs.

| File              | Read when…                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| `nodes.md`        | Scheduling a pod, adding node selectors/tolerations, GPU workloads, storage class choice by node |
| `apps.md`         | Checking if an app exists, finding its namespace, understanding what's deployed                  |
| `networking.md`   | Adding ingress (HTTPRoute), enabling SSO, configuring Gatus monitoring, DNS                      |
| `storage.md`      | Adding a PVC, wiring kopiur backup, connecting to CNPG, choosing a storage class                 |
| `secrets.md`      | Creating an ExternalSecret, adding aKeyless credentials, understanding cluster-secrets vars      |
| `components.md`   | Adding kopiur/cnpg/auth/zeroscaler to an app — exact `ks.yaml` stanzas                           |
| `docker-hosts.md` | Working on TrueNAS/Unraid/VPS docker-compose services, doco-cd GitOps                            |
| `teardown.md`     | Removing or replacing infrastructure — an operator, a CRD-owning chart, a metrics provider       |

Writing or reviewing a `ks.yaml`? That's ADR-0002, not a context file.

For sub-directory specifics not covered above, read that directory's `README.md` (e.g. `kubernetes/bootstrap/cnpg/README.md`).

---

## Decisions — `docs/adr/`

Read the ADRs touching the area you're about to work in. Don't re-litigate a recorded decision; if you think one is wrong, supersede it.

| #                                                                      | Decision                                                        | Date       | Status                  |
| ---------------------------------------------------------------------- | --------------------------------------------------------------- | ---------- | ----------------------- |
| [0001](docs/adr/0001-follow-onedr0p-cluster-template.md)               | Follow onedr0p's cluster-template and his home-ops patterns     | 2025-03-24 | accepted · living table |
| [0002](docs/adr/0002-flux-repository-conventions.md)                   | Flux repository conventions                                     | —          | accepted · living table |
| [0003](docs/adr/0003-external-secrets-akeyless-over-sops.md)           | External Secrets Operator with aKeyless, replacing SOPS         | 2025-04-06 | accepted                |
| [0004](docs/adr/0004-cloudnativepg-for-postgresql.md)                  | CloudNativePG for PostgreSQL                                    | 2025-04-21 | accepted                |
| [0005](docs/adr/0005-volsync-for-pvc-backup.md)                        | VolSync for PVC backup                                          | 2025-04-23 | superseded by 0013      |
| [0006](docs/adr/0006-authentik-for-sso.md)                             | Authentik for SSO                                               | 2025-05-01 | superseded by 0014      |
| [0007](docs/adr/0007-keda-for-scale-to-zero.md)                        | KEDA for scale-to-zero                                          | 2025-06-14 | superseded by 0010      |
| [0008](docs/adr/0008-envoy-gateway-over-ingress-nginx.md)              | Envoy Gateway over ingress-nginx                                | 2025-10-21 | accepted                |
| [0009](docs/adr/0009-pangolin-for-external-ingress.md)                 | Pangolin for external ingress                                   | 2026-05-02 | superseded by 0015      |
| [0010](docs/adr/0010-zeroscaler-over-keda.md)                          | zeroscaler (native HPA + prometheus-adapter) over KEDA          | 2026-05-17 | accepted                |
| [0011](docs/adr/0011-pgvector-cluster-split.md)                        | Separate pgvector cluster for vector workloads                  | 2026-05-21 | accepted                |
| [0012](docs/adr/0012-konflate-over-flux-local.md)                      | konflate (flate) over flux-local                                | 2026-06-18 | accepted                |
| [0013](docs/adr/0013-kopiur-over-volsync.md)                           | kopiur over VolSync for PVC backup                              | 2026-07-05 | accepted                |
| [0014](docs/adr/0014-pocket-id-tinyauth-over-authentik.md)             | pocket-id and tinyauth over Authentik                           | 2026-08-05 | accepted                |
| [0015](docs/adr/0015-towonel-over-pangolin.md)                         | towonel over Pangolin for public ingress                        | 2026-08-08 | accepted                |
| [0016](docs/adr/0016-no-http3-on-envoy-gateways.md)                    | No HTTP/3 on the Envoy gateways                                 | 2026-08-10 | accepted                |
| [0017](docs/adr/0017-akeyless-github-action-for-ci-secrets.md)         | aKeyless GitHub Action for CI secrets, over GitHub secrets      | 2026-08-13 | accepted                |
| [0018](docs/adr/0018-soul-for-identity-channel-prompts-for-rules.md)   | SOUL.md carries identity; channel_prompts carry room rules      | 2026-08-16 | accepted                |
| [0019](docs/adr/0019-agent-opens-prs-cannot-land-them.md)              | The Hermes agent opens pull requests and cannot land them       | 2026-08-16 | accepted                |
| [0020](docs/adr/0020-modelpool-router-for-gpu-swapping.md)             | One GPU slot, swapped on request, arbitrated by LLMKube         | 2026-08-18 | accepted                |
| [0021](docs/adr/0021-blue-green-rename-then-in-place-major-upgrade.md) | Rename CNPG clusters by promoting a replica; upgrade separately | 2026-09-03 | accepted                |

**0005, 0006, 0007 and 0009 are reconstructed** — written after the fact from the commits that removed them, not from contemporaneous notes. Each says so. Trust their consequences more than their rationale.

---

## Also

- **`docs/WORKLOG.md`** — active work, known issues, blocked items. Check before proposing work that may already be underway or known-broken.
- **`docs/agents/`** — how agents should consume this documentation (`domain.md`), issue-tracker conventions, triage labels.
- **`MIGRATION.md` files** — long-form migration narratives, referenced from the ADR they belong to. Currently `docker/vps/` (Pangolin→towonel) and `kubernetes/apps/network/envoy-gateway/` (nginx→Envoy, marked historical).
