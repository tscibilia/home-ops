# add-app is a prose procedure, not a scaffolder

**Status:** accepted
**Date:** 2026-11-23

The `add-app` skill scaffolds `kubernetes/apps/{namespace}/{app}/` by reading live repo state — `docs/context/` for stanzas, and one reference app per branch for full shapes — instead of carrying its own templates or a generator script.

The previous version embedded roughly ten YAML templates. They drifted: 4-space indentation in a 2-space repo, a harness-specific question API, and a chart version read from a single app. Each app differs in env vars, config files, probes, ports, and feature mix, so a generator would be a second, weaker copy of the app tree. The docs are already generated from disk and checked by `just docs test` in lefthook; that is the determinism the skill relies on.

## Consequences

- `docs/context/` is the source of truth for stanzas. The skill names sections; it does not restate them.
- Reference apps are the source of truth for full shapes. A renamed or deleted anchor is a documentation bug; the follow-up check is tracked in the worklog.
- Generated YAML is verified rather than assumed: `flate test all`, `kustomize build`, `just docs generate`, and `just docs test`.
- A missing mandatory input stops the run; the skill does not emit `TODO` or `latest` placeholders.
- The cost is more files read per run, and the anchors must stay representative.
