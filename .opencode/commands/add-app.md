---
description: Scaffold a new app in the home-ops monorepo
---

# Add app

@.agents/skills/add-app/SKILL.md

Follow the skill above exactly to scaffold: $ARGUMENTS

**Ask all five input batches before generating anything.** The skill is explicit
that you must never infer or skip a batch from the arguments passed in. Treat
`$ARGUMENTS` as a starting hint for the app name only, and still confirm it
along with everything else.

Namespaces currently in use:

!`ls kubernetes/apps/`

Then work the phases in order:

1. **Gather inputs** → verify: all five batches asked and answered, nothing assumed
2. **Research** → verify: chart and `postgres-init` versions read from the repo as
   it is now, not from memory
3. **Generate manifests** → verify: only the components, `dependsOn`,
   `healthChecks`, and `postBuild.substitute` entries the answers actually call for
4. **Register the app** → verify: it appears in the namespace kustomization

Before handing back:

- `flate test all` passes
- `just docs generate` has been run — adding an app changes a generated docs
  section, and `just docs test` gates it pre-commit
- the affected `docs/context/` file is updated in the same change
- give me a commit message; **do not commit yourself** (GPG restriction)
