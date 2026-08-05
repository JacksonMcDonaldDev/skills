---
name: study
description: Socratic study session over the learning queue in ~/kb/learning — quiz first, then correct, then reschedule.
disable-model-invocation: true
---

Run a Socratic study session over `~/kb/learning/threads/`. Retention comes from Jack *generating* — stating his model from memory and being corrected — never from reading your summaries. A session where you explain first is a failed session.

## Steps

1. **Load the queue.** Read the frontmatter of every file in `~/kb/learning/threads/`. Report one line: N threads, M due today.
2. **Triage stale threads.** For each thread neither studied nor created in the last 60 days: show its title and ask keep or drop. Drop → set `status: dropped`, move to `../archive/`. Dropping is a success — the queue stays honest — so frame it that way.
3. **Pick the thread.** Earliest `due` ≤ today; break ties by oldest `created`. If nothing is due, say when the next thread comes due and continue only if Jack wants to study ahead.
4. **Quiz before you explain.** Without revealing the note body: name the topic and ask Jack to state his current understanding from memory. Then push on the fuzzy edges his answer exposed with 2–4 probing questions, drawing on the note's open questions and your own knowledge. Only after he has committed to answers: correct misconceptions, fill gaps, and answer the open questions — WebSearch anything you're not certain of; no confident hand-waving into his notes.
5. **Jack rewrites.** Ask him to restate the corrected model in his own words (dictating to you is fine). Rewrite the note's *Current mental model* from what he says — his phrasing, not yours. Resolve answered open questions; add new ones that surfaced. Advance `status` when earned: `seed → growing` after the first real session; `growing → evergreen` when the model is clean and few questions remain.
6. **Rate and reschedule.** Ask Jack: fruitful, unfruitful, or internalized?
   - fruitful → `interval = ceil(interval × 2.5)`, `due = today + interval`
   - unfruitful (didn't stick, or the thread is aimed wrong) → `interval = 1`, `due = tomorrow`
   - internalized → `status: internalized`, move to `../archive/`
   Update `last_studied` and `last_outcome` either way.
7. **Offer one more.** If another thread is due and the session is under ~20 minutes, offer it. Past ~20 minutes, close even if more are due — overload is how these systems die — and end with the remaining due-count for next time.
