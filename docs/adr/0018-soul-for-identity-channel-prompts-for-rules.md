# SOUL.md carries identity; per-room operating rules live in channel_prompts

**Status:** accepted
**Date:** 2026-08-16

Hermes reads `$HERMES_HOME/SOUL.md` as slot #1 of the system prompt, replacing its built-in identity outright. home-ops ships that file as `kubernetes/apps/ai/hermes/app/resources/SOUL.md` through a `configMapGenerator`, and the `02-init-config` initContainer copies it over `/opt/data/SOUL.md` on every start. It carries voice, disposition and universal restrictions only. Everything specific to a room — the homelab operating manual for `#hermes-k8s`, the assistant brief for `#hermes-aid` — lives in `discord.channel_prompts`, keyed by Discord channel ID.

## Considered options

**Let the agent own SOUL.md on the PVC.** "The agent that grows with you" implies the identity file should be the agent's to rewrite. It cannot: no tool writes SOUL.md, and `tools/threat_patterns.py` classifies an injected instruction to edit it as a prompt-injection signature. The surfaces that do grow are the memory provider (memini, `MEMINI_NAMESPACE=tscibilia/hermes`) and the skills the agent authors under `/opt/data/skills` — both on the PVC, both untouched by this decision. GitOps ownership therefore costs no adaptability and buys review plus survival of a PVC loss.

**One SOUL.md carrying the operating rules too.** Rejected on two grounds. Hermes joins three prompt tiers and SOUL sits in `stable`, which is built once per session and used as the upstream prefix cache; room-specific text there forks that prefix per room. Separately, the upstream guide draws the line explicitly — tone and disposition in SOUL.md, project rules in AGENTS.md — and calls confusing the two its most common mistake.

**Hermes profiles.** The obvious answer, and the one community writing points at: `$HERMES_HOME/profiles/<name>/SOUL.md`. A profile is not a persona inside one agent but a separate instance — `hermes_cli/container_boot.py` reconciles "per-profile gateway s6 services", one gateway process per profile, each with its own `config.yaml`, `.env`, `SOUL.md` and skills. The deployment runs a single `gateway run`, so a second SOUL would mean a second gateway and a second Discord bot token to separate two rooms that differ only in subject matter.

## Consequences

- `channel_prompts` are appended below SOUL in the `context` tier, never replacing it. A forum parent's entry also covers its child threads, and an unmatched key is silently ignored — a stale channel ID fails quiet, with no error anywhere.
- Channel IDs are quoted in YAML so the keys stay strings.
- The initContainer copy is unconditional and overwrites anything already at `/opt/data/SOUL.md`. That is the point, and it is what makes the file in git the only source worth reading.
- Project rules are **not** auto-loaded. Hermes discovers AGENTS.md from `terminal.cwd` (`/opt/data/workspace`) at session start, first-match-wins against `.hermes.md`/`CLAUDE.md`/`.cursorrules`, and the prompt is built once — `cd`-ing into a clone mid-session does not reload it. The `#hermes-k8s` prompt therefore tells the agent to read AGENTS.md and CONTEXT.md explicitly rather than assume them. Pointing `terminal.cwd` at a pre-cloned repo would make the load automatic and is the obvious follow-up.
