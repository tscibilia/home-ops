---
description: Scaffold a new app in the home-ops monorepo
---

# Add app

@.agents/skills/add-app/SKILL.md

Follow the skill above exactly to scaffold: $ARGUMENTS

Treat `$ARGUMENTS` as a hint for the app name only; ask for every mandatory input
the skill lists that the arguments do not supply.

Namespaces currently in use:

!`ls kubernetes/apps/`

Then work the skill's steps in order:

1. **Collect the inputs** → verify: every mandatory value supplied, nothing guessed
2. **Read the sources** → verify: versions and stanzas read from the repo as it is now
3. **Write the app** → verify: only the components, `dependsOn`, health checks, and
   substitutions the answers call for
4. **Register** → verify: the app is in the namespace index and `just docs generate` ran
5. **Verify** → verify: `flate test all`, `kustomize build`, and `just docs test` are each
   reported with their own result
6. **Report** → verify: every gap is listed as `file: key — needs X`

Before handing back, give me a commit message; **do not commit yourself** (GPG
restriction).
