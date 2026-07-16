---
name: ship
description: Implement work from a spec or tickets, test-first, then review.
argument-hint: "Which spec or tickets should I implement?"
disable-model-invocation: true
---

Implement the work the user described.

These steps are mandatory and in order:

1. Invoke the `tdd` skill. Use it at pre-agreed seams.
2. Typecheck and run the affected test file after each seam.
3. Run the FULL suite. It must pass.
4. Invoke the `code-review` skill.
5. Commit to the current branch.

Steps 1 and 4 mean actually invoking those skills via the Skill tool — not
mentioning them. If a step cannot be completed, stop and say so rather than
skipping it silently.
