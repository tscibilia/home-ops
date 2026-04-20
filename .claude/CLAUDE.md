# CLAUDE.md

Home-ops monorepo. Kubernetes cluster managed with Flux CD GitOps on three bare-metal Talos nodes with Rook Ceph storage. Also includes Docker-based server configs for other homelab services.

**Repo layout:**
- `/kubernetes/` — everything K8s cluster related:
  - `apps/` — Flux-managed app manifests
  - `talos/` — Talos OS config (minijinja templates + node patches)
  - `bootstrap/` — Helmfile initial cluster setup (cilium, coredns, external-secrets, etc.)
- `/docker/` — additional homelab server configs

## Karpathy Skills

**Behavioral guidelines to reduce common LLM coding mistakes. These guidelines bias toward caution over speed. For trivial tasks, use judgment.**

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## CRITICAL: Environment Setup

All tools (kubectl, talosctl, just, flux, helm) are managed by mise and require explicit activation:

```bash
eval "$(mise activate zsh)" && <command>
```

The Bash tool does NOT auto-source `~/.zshenv`. Always prefix commands with the above.

## Task Runner

`just` with three modules: `bootstrap`, `kube`, `talos`.

**Most-used `just kube` commands:**
- `sync-ks <ns> <name>` / `sync-hr <ns> <name>` / `sync-es <ns> <name>` — force sync single resource
- `ks-reconcile <ns> <name>` / `hr-reconcile <ns> <name>` — reconcile from source
- `ks-reconcile-all` / `hr-reconcile-all` — reconcile everything
- `ks-restart` / `hr-restart` — suspend/resume all failed resources
- `apply-ks <ns> <ks>` — validate locally with flux-local before pushing
- `browse-pvc <ns> <claim>` — mount PVC to debug pod
- `node-shell <node>` — interactive shell on node
- `view-secret <ns> <secret>` — decode and view secret
- `snapshot <ns> <name>` / `volsync-restore <ns> <name> <previous>` — VolSync backup/restore
- `restart-network` — restart network stack in order

**`just talos` commands:**
- `apply-node <node>` — apply config to node
- `upgrade-node <node>` / `upgrade-k8s <version>` — upgrades

## App Structure

```
kubernetes/apps/{namespace}/{app-name}/
├── ks.yaml                  # Flux Kustomization — deps, postBuild substitutions, components
├── app/
│   ├── kustomization.yaml   # Kustomize — resources, configMapGenerator, patches
│   ├── helmrelease.yaml     # Chart ref + values
│   ├── ocirepository.yaml   # Helm chart source
│   ├── externalsecret.yaml  # aKeyless → Kubernetes Secret
│   └── referencegrant.yaml  # Cross-namespace gateway access
└── namespace.yaml
```

`ks.yaml` is the entry point. It defines `dependsOn`, `postBuild.substitute`/`substituteFrom`, and `components`.

## Kustomize Components (`/kubernetes/components/`)

Include via `components: [../../../../components/<name>]` in `ks.yaml`:
- `common/` — standard alerts + secrets for all namespaces
- `cnpg/` — DB user init CronJob + ExternalSecret
- `ext-auth-internal/` / `ext-auth-external/` — Authentik SSO via Envoy forward auth
- `keda/` — KEDA ScaledObject auto-scaling
- `volsync/` — PVC backup/restore (requires `APP` and `VOLSYNC_CAPACITY` substitutions)

## Storage Classes

Only 3 storage classes exist:
- **`ceph-ssd`** (default) — Rook Ceph, Samsung SSDs — all persistent workloads
- **`openebs-hostpath`** — local node storage — CNPG clusters, victoria-logs, actions-runner
- **`nfs-media`** — external NFS — media library

## Shared Infrastructure

**CNPG clusters** (in `database` namespace):
- `pgsql-cluster` — general PostgreSQL 17 (`ghcr.io/cloudnative-pg/postgresql:17`)
- `immich17` — PostgreSQL 17 + vectorchord (`ghcr.io/tensorchord/cloudnative-vectorchord:17.5-0.4.2`)

Apps declare: `dependsOn: [{name: cnpg-cluster, namespace: database}]`

**Service endpoints:**
- DB (read-write): `<cluster>-rw.database.svc.cluster.local`
- Cache: `dragonfly-cluster.database.svc.cluster.local:6379` (immich=db2, searxng=db3)
- Authentik outpost: `ak-outpost-authentik-embedded-outpost.default.svc.cluster.local:9000`

## Secrets

All secrets in aKeyless → synced via `ExternalSecret` CRDs. Cluster-wide vars injected via `postBuild.substituteFrom: cluster-secrets`.

## Networking

- **SSO Auth**: `ext-auth-external` (Authentik forward auth) + `ext-auth-internal` (Authentik forward auth, LAN only) — for apps without native OIDC support
- **Ingress**: `envoy-external` (cloudflared tunnel) + `envoy-internal` (LAN only)
- **DNS**: CoreDNS (cluster), unifi-dns (LAN → UniFi), external-dns (Cloudflare)
- **VPN**: Multus CNI secondary interface (net1, 192.168.99.0/24) — qBittorrent
- **Cross-namespace**: Requires `ReferenceGrant` when HTTPRoute/SecurityPolicy references Service in another namespace

## Conventions

- YAML anchors: `name: &app foo` referenced as `*app`
- Renovate annotations: `# renovate: datasource=docker depName=...` on image tags
- `configMapGenerator` in `kustomization.yaml` to embed config files, mounted via HelmRelease
- Always declare `dependsOn` in `ks.yaml` — never assume deployment order

## Modifying Apps

1. New app: use the skill `add-app`
2. Secrets: add to aKeyless → reference in `externalsecret.yaml`
3. Test before push: `just kube apply-ks <ns> <app>` (flux-local validation)
4. Force sync after push: `just kube ks-reconcile <ns> <app>`
5. `kubectl edit` changes are ephemeral — Flux resets them
6. Update docs: use skill `update-docs`, triggered by "add X to docs", "update docs", "reflect changes in docs"

## Troubleshooting

### Flux / GitOps
- `kubectl edit` changes are ephemeral — Flux resets them. Always edit, `git add <dir/> && git commit -m`. Flux will auto-reconcile.
- Check Kustomization failures: `eval "$(mise activate zsh)" && kubectl get ks -A | grep -v True`
- If a HelmRelease is stuck in a bad state, delete it and let Flux recreate: `kubectl delete hr <name> -n <ns>`

### Talos
- No SSH — all node access via `talosctl -n <node-ip>`
- Configs are generated from minijinja templates in `kubernetes/talos/`. Never edit rendered output directly; edit the templates and run `just talos apply-node <node>`.
- Upgrade order matters: Talos first (`just talos upgrade-node <node>`), then Kubernetes (`just kube upgrade-k8s <version>`)

### Cilium
- kube-proxy does not exist — Cilium is the eBPF replacement. Standard kube-proxy debug tools won't apply.
- LoadBalancer IP unreachable → check `CiliumL2AnnouncementPolicy` and `CiliumLoadBalancerIPPool`
- Use `cilium` CLI (or Hubble) for network/policy debugging, not iptables

### CNPG
- Two clusters with different images — don't mix them up: `pgsql-cluster` (standard PG17) and `immich17` (vectorchord)
- Read-write endpoint: `<cluster>-rw.database.svc.cluster.local` — always use `-rw` for app connections
- Recovery from scratch uses B2 backups via `just bootstrap cnpg` — don't try to manually recreate clusters
- Check cluster health: `kubectl get cluster -n database` and inspect `.status.conditions`

### VolSync
- Restore flow: suspend app → delete existing PVC → create new PVC with `dataSourceRef` → VolSync Volume Populator auto-populates → resume app
- Use `just kube volsync-restore <ns> <name> <previous>` which handles the suspend/delete/restore sequence
- If backup jobs are failing repeatedly with lock errors: `just kube volsync-unlock`
- Check available snapshots before restoring: `just kube volsync-list <ns> <name>`

## Active Work & Known Issues

Check [`../ACTIVE-WIP.md`](../ACTIVE-WIP.md) at the start of any task for:
- **In Progress** — ongoing work to avoid conflicts or duplication
- **Known Issues** — active bugs/limitations to be aware of
- **Blocked** — items waiting on external dependencies
- **Resolved/Unresolved** — history and closed-as-won't-fix decisions
