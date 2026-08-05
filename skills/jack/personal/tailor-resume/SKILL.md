---
name: tailor-resume
description: Tailor a Reactive Resume JSON export to a specific job posting, emitting a new JSON in the identical schema plus a gap report. ONLY run when the user explicitly types /tailor-resume — do NOT auto-trigger on general resume talk ("help with my resume", "review my CV"). Personal skill for bigbox; master resume defaults to ~/Downloads/master-resume.json.
---

# tailor-resume

Tailors a [Reactive Resume](https://rxresu.me) JSON export to one job posting. Produces a
new JSON file in the **identical schema** (re-importable into Reactive Resume) plus a
`.gaps.md` interview-prep report. Strictly truthful: it reorders, rewords, re-emphasises,
and selects content already in the master — it never invents facts.

**Activation:** run ONLY on an explicit `/tailor-resume`. Do not fire proactively.

## Inputs

1. **Master resume path** — defaults to `~/Downloads/master-resume.json`. Always announce
   the default ("Using `~/Downloads/master-resume.json` as master — pass a path to
   override.") so the user can redirect. Read it; if it's missing or unparseable, **stop
   and ask**.
2. **Job description** — accept, in priority order:
   - pasted text (the normal path),
   - a local file path (read it),
   - a URL (attempt `WebFetch`; if it fails — most ATS/LinkedIn pages block fetches —
     fall back to "I couldn't retrieve that, paste the text").
   If no JD is provided, **stop and ask** before doing anything.

Never proceed with a missing/unreadable master or JD.

## The schema (what you're editing)

It's a Reactive Resume export. The fields you may touch are a small subset; everything
else is reproduced **byte-for-byte**.

**Editable surface:**
- `summary.content` — HTML string (`<p>…</p>`). Rewrite the prose.
- `sections.experience.items[].description` — HTML bullets (`<ul><li><p>…</p></li></ul>`).
  Reword, reorder, and drop individual bullets. **Preserve the HTML structure exactly.**
- `sections.skills.items[].keywords` — reorder so job-relevant terms come first; may drop
  irrelevant keywords. **Never add a keyword not already present** (truthfulness).
- `basics.headline` — mirror the posting's role-title language (it's a self-description,
  so rephrasing is fine as long as it's not a false claim).

**Frozen — reproduce verbatim, do not reformat or re-key:**
- All of `metadata`, `picture`, `design`, `typography`, `page`, `layout`, `customSections`.
- Every `id`. All `period` / `location` / `company` / `school` / `website` / dates.
- Education, awards, certifications, and every other section's items (not editable at all).
- `basics` apart from `headline`. `summary` apart from `content`.
- **Every `hidden` flag** — section-level and item-level. You optimise within the visible
  set only; never reveal or bury anything.

## Hard rules

- **Truthfulness (the backbone).** The output contains **no fact absent from the master**.
  No invented skills, metrics, employers, tools, or accomplishments. Rephrasing to mirror
  the JD's terminology is allowed **only** when the master genuinely supports it (e.g. JD
  says "CI/CD pipelines", master says "GitHub Actions" → "CI/CD pipelines (GitHub Actions)").
- **Selection, not addition.** You may drop irrelevant bullets/keywords, but:
  - never remove a whole experience item or a whole skill group,
  - keep a **floor of 1 bullet** per experience role,
  - never empty a skill group to zero keywords.
- **Exact-term keyword mirroring**, constrained by the truthfulness rule. ATS filters match
  literally — prefer the JD's exact wording for experience you actually have.
- **Soft length budget** (one-page footprint): aim for summary ≤ ~4 sentences and roughly
  6–9 total experience bullets. Relevance wins ties — never amputate a high-relevance
  bullet just to hit a number.

## Procedure

1. **Resolve inputs** (above). Announce the master default.

2. **JD-analysis pre-pass — print this to chat before writing anything.** Extract from the
   posting and show the user:
   - the exact **role title**,
   - **hard requirements** (must-have skills / tools / years),
   - **ATS keywords** (specific terms a filter would scan for),
   - **implicit priorities** (what the role really optimises for — e.g. ship-fast vs
     scale-reliability),
   - a short **mapping** of each requirement → where the master supports it (or doesn't).
   Then proceed straight to tailoring (show-then-proceed; no approval gate). The user can
   course-correct with a follow-up if you misread the JD.

3. **Tailor** the editable fields per the rules. Lead the summary and each role's bullets
   with what this job cares about. Reorder skill keywords. Mirror the title in `headline`.

4. **Build the gap report.** Every hard requirement / ATS keyword the master does NOT
   genuinely support → list it. This is the user's interview-prep sheet ("they want
   Kubernetes; you have no container-orchestration evidence").

5. **Write the outputs** to a **per-company subfolder** `~/resumes/tailored/{company}/`
   (create the subfolder, and its parents, if missing). `{company}` = the company name
   slugified (lowercase, hyphens); fall back to a timestamp if the company can't be parsed.
   Inside that folder write:
   - `{slug}.json` — the tailored resume. `{slug}` = `{company}-{role-title}` slugified
     (lowercase, hyphens); fall back to a timestamp if company/role can't be parsed.
   - `{slug}.gaps.md` — the gap report.
   **Never write to the master path.** If `{slug}.json` already exists in the subfolder,
   suffix `-2`, `-3`, … rather than overwrite. Reuse an existing company subfolder for
   repeat applications to the same company — only the filenames disambiguate per role.

6. **Validate — do not declare done until this passes.** Run the bundled checker:
   ```sh
   python3 ~/.claude/skills/tailor-resume/scripts/validate.py <MASTER_PATH> ~/resumes/tailored/{company}/{slug}.json
   ```
   It asserts the output parses as JSON, that every frozen field is byte-identical to the
   master, that no item was added or removed, that skill keywords are a subset of the
   master's, and that the 1-bullet floor holds. **If it fails, fix the offending fields and
   re-run until it passes.** A validation failure means you mutated something frozen or
   invented a keyword — repair, don't rationalise.

7. **Report** to the user: the output paths, a 2–3 line summary of what you emphasised, and
   the gap report inline.

## Notes

- The summary and experience descriptions are **HTML**, not plain text. Keep tags intact
  (`<ul><li><p>…</p></li></ul>`); only change the text inside.
- Output is disposable and per-application — the master is the single source of truth and
  is never modified. The user re-imports `{slug}.json` into Reactive Resume.
- If the user wants latent content (e.g. a hidden award) in play, that's their call to
  un-hide in the master *before* running — this skill won't touch `hidden` flags.
