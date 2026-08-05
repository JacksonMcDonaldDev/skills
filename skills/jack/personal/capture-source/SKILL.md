---
name: capture-source
description: Capture a source (YouTube video, article, local file) into the learning KB — file the raw material, distill a source note, and link it into the knowledge web.
disable-model-invocation: true
argument-hint: "URL or file path of the source to capture"
---

Capture a source into the learning KB at `~/learning-kb` (clone of `github.com/JacksonMcDonaldDev/learning-kb`). The KB's `CLAUDE.md` is the authority on conventions — read it first; if anything below conflicts with it, the KB wins.

## Procedure

1. **Locate the KB.** `~/learning-kb` must exist and be the learning KB (check its `CLAUDE.md`). If it's missing on this machine, stop and ask rather than creating one.

2. **Get the material.** If the source content is already in this session's context (e.g. a transcript pulled earlier), reuse it — don't refetch.
   - YouTube → `/youtube-transcript` skill
   - Web article → WebFetch
   - Local file → read it

3. **File the raw source.** Write it verbatim to `sources/raw/YYYY-MM-DD-<kebab-slug>.md` (date = today, capture date) with frontmatter: `url`, `type` (video-transcript | article | book-excerpt | …), `people`, `captured`, `distilled-note` (title of the note from step 4). Raw files are immutable once written.

4. **Distill a source note.** One Title Case note in `notes/` covering what *this source* teaches, organized by theme. Preserve the few best lines as verbatim quotes. Link out with `[[wikilinks]]` to concept notes — existing ones, or ones worth creating (a dangling wikilink is a valid marker for later).

5. **Promote concepts.** Ideas durable beyond this one source become concept notes (one unit of learning each) — create new ones or extend existing ones, citing the source note at the bottom. Don't force it: a thin source may promote nothing.

6. **Wire the web.** Every new note must be reachable from an index note; new index notes get listed in `INDEX.md`. Add the source to `INDEX.md`'s Sources section. If the source is from a person the KB tracks, update their person index.

7. **Commit and push.** One commit: `capture: <short source description>`.
