# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. In multi-context repos, also check `src/<context>/docs/adr/` for context-scoped decisions.
- **`docs/context/`** — read the file(s) covering the scoped area you're about to touch, organized into nine topic files (`01_nodes.md` … `09_interactions.md`).
- **`docs/WORKLOG.md`** — Status tracker used to support github issues. Check before proposing work that may already be underway or already known-broken.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo:

```
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   │   ├── 0001-rook-ceph-over-longhorn.md
│   │   └── 0002-cilium-over-flannel.md
│   ├── context/
│   │   ├── 01_nodes.md
│   │   ├── …
│   │   └── 09_interactions.md
│   └── agents/
├── kubernetes/
└── docker/
```

`docs/context/` and `docs/adr/` split by tense. `docs/context/` records how things are wired **now** — state, updated in place as the cluster changes. `docs/adr/` records **why** a choice was made, written once and never edited except to mark it superseded. If you're about to add rationale to a context file, it belongs in an ADR instead.

## Keep the reference docs current

`docs/context/` is only useful while it's true. When a change makes one of those files wrong, fix it in the same change.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids. If the concept you need isn't in defined yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it).

## Flag conflicts

If your output contradicts an ADR or something stated in `docs/context/` or `docs/adr/`, surface it explicitly rather than silently overriding:

> _Contradicts `07_flux_conventions.md` (always declare dependsOn) — but worth reopening because…_
