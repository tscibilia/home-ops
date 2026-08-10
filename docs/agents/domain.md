# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the map. Glossary, the routing table for `docs/context/`, and the ADR index. Start here.
- **`docs/adr/`** — read the ADRs touching the area you're about to work in. `CONTEXT.md`'s index says what each covers, so you don't have to open all of them.
- **`docs/context/`** — read the file(s) covering the scoped area you're about to touch. One file per topic, named for it; `CONTEXT.md`'s routing table says which to open.
- **`docs/WORKLOG.md`** — Status tracker used to support github issues. Check before proposing work that may already be underway or already known-broken.

## File structure

```
/
├── CONTEXT.md                 # map: glossary · state routing · ADR index
├── docs/
│   ├── adr/
│   │   ├── 0001-follow-onedr0p-cluster-template.md
│   │   ├── 0002-flux-repository-conventions.md
│   │   └── …0015
│   ├── context/           # one file per topic, routed from CONTEXT.md
│   ├── scripts/           # generate.py — renders the generated doc blocks
│   └── agents/
├── kubernetes/
└── docker/
```

`docs/context/` and `docs/adr/` split by tense. `docs/context/` records how things are wired **now** — state, updated in place as the cluster changes. `docs/adr/` records **why** a choice was made, written once and never edited except to mark it superseded. If you're about to add rationale to a context file, it belongs in an ADR instead.

## Writing an ADR

**Name:** `NNNN-slug.md`, zero-padded to four digits, slug in kebab-case. Number by scanning `docs/adr/` for the highest and incrementing.

**Offer an ADR only when all three hold** — otherwise it's a convention or a state change, not a decision:

1. **Hard to reverse** — changing your mind later carries real cost.
2. **Surprising without context** — a future reader would look at the repo and ask "why on earth is it like this?"
3. **A real trade-off** — genuine alternatives existed and one was picked for stated reasons.

**Shape:** a title, a `**Status:**` line, a `**Date:**` line, then one to three sentences of context-decision-why. Add `## Considered options` or `## Consequences` only when they carry something non-obvious. Pointer lines (`**Supersedes:**`, `**Reconstructed:**`) go with Status.

**Superseding:** leave the old file in place, flip its `**Status:**` to `superseded by ADR-NNNN`, and link forward. The new ADR names only what it _directly_ replaced — one hop — so reading backwards reconstructs the chain in order. Update the row in `CONTEXT.md`'s index.

**Reconstructed ADRs** carry `**Reconstructed:** from <sha> (<date>)` and a closing note. These were written after the fact from the commit that _removed_ the thing, so their consequences are evidence and their rationale is inference. Never write a new one without the marker.

### The two living records

`0001` and `0002` are the only exceptions to write-once, and they are exceptions in a narrow way: each carries a table whose **`Status` column** changes over time, and nothing else in either file is edited.

- **ADR-0001** is the predecessor of record. Its baseline table lists what the cluster inherited; a row's Status flips to `superseded by ADR-NNNN` when a later decision replaces that element. The ADR itself stays `accepted` permanently.
- **ADR-0002** holds the Flux conventions plus the reference material for writing a conforming `ks.yaml`. Its convention rows change status, and its reference sections are updated in place as tooling changes.

Do not add a third living record. If something needs continuous updating, it is state — it belongs in `docs/context/`.

## Keep the reference docs current

`docs/context/` is only useful while it's true. When a change makes one of those files wrong, fix it in the same change.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids. If the concept you need isn't in defined yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it).

## Flag conflicts

If your output contradicts an ADR or something stated in `docs/context/` or `docs/adr/`, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0002 (always declare dependsOn) — but worth reopening because…_
