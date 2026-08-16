---
description: Apply the four Karpathy guidelines to the current work
---

# Karpathy guidelines

@.agents/skills/karpathy-guidelines/SKILL.md

The guidelines above are the standing rules for this repo — `AGENTS.md` makes
them mandatory, not advisory.

Apply them to: $ARGUMENTS

If no scope was given, apply them to the change currently in progress:

!`git --no-pager diff HEAD --stat | tail -25`

Work the four rules in order and answer concretely for this change:

1. **Think before coding** — state your assumptions. If two readings of the
   request exist, name both instead of picking one silently.
2. **Simplicity first** — is there a smaller version that solves the same
   problem? Name anything speculative: unused flexibility, single-use
   abstractions, error handling for impossible cases.
3. **Surgical changes** — does every changed line trace to the request? Flag any
   adjacent cleanup, reformatting, or refactoring that crept in. Orphans _your_
   change created should go; pre-existing dead code should only be mentioned.
4. **Goal-driven** — restate the task as `[step] → verify: [check]`, where each
   check is a command that actually proves the step.

Report only what fails a rule and what you would change instead. If the work
already satisfies a rule, say so in one line — do not pad.
