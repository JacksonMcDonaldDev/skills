---
name: learn
description: Capture an unfamiliar concept as a thread in the learning queue (~/kb/learning/threads/). Use when the user invokes /learn or asks to file something for later study, or when mid-task he's clearly wrestling with a concept new to him — then offer to capture it.
---

Capture a fleeting learning thread: one markdown file in `~/kb/learning/threads/` recording a concept Jack met but doesn't yet own. Capture is deliberately dumb and cheap — depth happens later, in `/study` sessions. Budget: ~15 seconds of Jack's attention, then back to the interrupted task.

If you reached this skill proactively (Jack didn't type `/learn` or ask for a capture), offer one line — "File *topic* in your learning queue?" — and continue only if he accepts.

## Steps

1. **Name the thread.** From the argument or the conversation, pick the single concept in play and a kebab-case slug (e.g. `git-packfiles`). Check `ls ~/kb/learning/threads/` for the slug or a near-match: if the thread already exists, merge the new context and open questions into it, leave its scheduling fields untouched, and skip to step 4.
2. **Draft all four sections from the conversation** — the confusion is usually already on the record:
   - *Context of encounter* — the task or moment where it came up
   - *Why it mattered* — what it blocked, or would have unlocked
   - *Current mental model* — Jack's rough understanding right now, in his terms, including what's fuzzy. This is the delta `/study` will close, so capture the fuzziness honestly rather than smoothing it over.
   - *Open questions* — concrete questions whose answers would close that delta
3. **Ask at most one question.** If exactly one load-bearing section is genuinely blank (usually the mental model), ask Jack one short question to fill it. Otherwise ask nothing.
4. **Write and return.** Write the file per the template, reply with one line — `Filed <slug> (N threads in queue)` — and pick the interrupted task back up.

## Template

```markdown
---
title: "<the concept, phrased as the question it answers>"
created: <today>
status: seed
tags: [<1-3 topic tags>]
due: <tomorrow>
interval: 1
last_studied:
last_outcome:
---

## Context of encounter
...

## Why it mattered
...

## Current mental model
...

## Open questions
- ...
```

The scheduling fields (`due`, `interval`, `last_studied`, `last_outcome`, `status`) belong to `/study`; at capture they are always exactly as shown above.
