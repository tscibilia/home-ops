# Follow onedr0p's cluster-template and his home-ops patterns

**Status:** accepted
**Date:** 2025-03-24

The cluster was created from [`onedr0p/cluster-template@2025.3.0`](https://github.com/onedr0p/cluster-template/tree/2025.3.0) rather than assembled from scratch, and where the template left a choice open the author's own [`onedr0p/home-ops`](https://github.com/onedr0p/home-ops) was followed as the reference implementation. The trade-off taken was template-over-bespoke: a working, opinionated, maintained stack in exchange for inheriting decisions that were never independently evaluated.

This ADR is the **predecessor of record**. Every later divergence supersedes a row in the table below rather than the ADR itself.

## Baseline

Rendered by the template at init (2025-03-24), or selected shortly after from the options its README recommended.

| Element                             | Source                | Status                 |
| ----------------------------------- | --------------------- | ---------------------- |
| Talos Linux                         | template              | accepted               |
| Flux CD (operator + instance)       | template              | accepted               |
| Cilium                              | template              | accepted               |
| CoreDNS                             | template              | accepted               |
| cert-manager                        | template              | accepted               |
| metrics-server                      | template              | accepted               |
| reloader                            | template              | accepted               |
| spegel                              | template              | accepted               |
| external-dns                        | template              | accepted               |
| echo                                | template              | accepted               |
| Rook Ceph                           | README recommendation | accepted               |
| OpenEBS (hostpath)                  | README recommendation | accepted               |
| SOPS + age                          | template              | superseded by ADR-0003 |
| ingress-nginx (internal + external) | template              | superseded by ADR-0008 |
| cloudflared                         | template              | superseded by ADR-0009 |
| k8s-gateway                         | template              | superseded by ADR-0008 |
| flux-local                          | template              | superseded by ADR-0012 |

**Editing rule:** this table's `Status` column is the one thing in `docs/adr/` that changes over time — a row is updated only to point at the ADR that superseded it. Nothing else in this file is edited. See `docs/agents/domain.md`.

## Considered options

The template's README presented storage as a menu — `rook-ceph / longhorn / openebs`, `democratic-csi`, `csi-driver-nfs`, `synology-csi`, `truenas-csi` — and shipped none of them. Rook Ceph (replicated) and OpenEBS (node-local) were selected from that menu on the same basis as the rest of this ADR: they are what the author runs.

## Consequences

- Upstream template changes are **not** tracked. The template has moved on since `2025.3.0` (it now ships Envoy rather than nginx, among other changes); this repo diverged independently and any resemblance to current upstream is coincidental.
- A baseline element being listed here does not mean it was evaluated. Where a later ADR supersedes one, that ADR carries the first real trade-off recorded for that slot.
