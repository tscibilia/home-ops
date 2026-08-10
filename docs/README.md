# docs

Documentation for the cluster — how it's wired, and why it ended up that way.

**Looking for something specific? Start at [`CONTEXT.md`](../CONTEXT.md).** It's the map: the glossary, a table saying which file answers which question, and the index of recorded decisions. This page explains the shape of the directory and how to change it.

## What's in here

| Path                       | Holds                                                                                                                                | Changes when                                        |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- |
| [`context/`](context/)     | How things are wired **now** — nodes, apps, networking, storage, secrets, components, docker hosts, teardown traps                   | The cluster changes                                 |
| [`adr/`](adr/)             | **Why** a choice was made, one decision per file                                                                                     | A new decision is made — never to revise an old one |
| [`agents/`](agents/)       | How coding agents should consume all of the above ([`domain.md`](agents/domain.md)), plus issue-tracker and triage-label conventions | The workflow changes                                |
| [`WORKLOG.md`](WORKLOG.md) | Active work, known issues, blocked items                                                                                             | Continuously                                        |
| [`scripts/`](scripts/)     | The generators and verifier behind `just docs`                                                                                       | Rarely                                              |

## Updating them

Three rules, and they're the whole contract:

**`context/` is edited in place.** It describes the present tense. If a fact stops being true, overwrite it — there's no history to preserve here, that's what git and `adr/` are for.

**`adr/` is written once.** An ADR records what was decided and why, at the time. If a decision turns out wrong, write a new ADR that supersedes it and update the old one's status — don't edit the reasoning. Two files are living exceptions; [`agents/domain.md`](agents/domain.md) says which and what may change in them.

**Some sections are generated.** Anything between `<!-- BEGIN GENERATED: … -->` markers is written by [`scripts/generate.py`](scripts/generate.py) from the repo itself — don't hand-edit inside them. Hand-written prose _inside_ a generated block is preserved across regeneration, keyed by row.

The same script writes `_sidebar.md` at the repo root — the navigation for the [published docs site](https://tscibilia.github.io/home-ops/), labelled from each file's H1. That one is generated whole, so anything typed into it is lost on the next run. Adding an ADR or a context file puts it in the nav automatically; nothing lists the pages by hand.

```sh
just docs generate   # rewrite the generated sections
just docs test       # gate: sections in sync, and every identifier named in the docs still resolves
```

`just docs test` also runs pre-commit via lefthook, so a stale table or a renamed component fails before it lands.

## The two files outside this directory

- [`CONTEXT.md`](../CONTEXT.md) — the map, at the repo root because it's the entry point for humans and agents alike. Vocabulary and navigation only; no state, no rationale.
- [`AGENTS.md`](../AGENTS.md) — instructions for coding agents: standing rules, the `just` task runner, repo layout, commit protocol. Points here rather than restating any of it.

For specifics no file above covers, read the owning directory's own `README.md` — for example [`kubernetes/bootstrap/cnpg/README.md`](../kubernetes/bootstrap/cnpg/README.md).
