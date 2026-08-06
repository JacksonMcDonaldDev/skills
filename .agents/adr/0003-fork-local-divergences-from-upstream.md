# Keep the fork's side of `CLAUDE.md` on an upstream merge

This repo is a fork of [mattpocock/skills](https://github.com/mattpocock/skills). `upstream/main` is merged in periodically, and almost all of that lands cleanly: the fork's own skills live under `skills/jack/`, a path upstream has never owned, and the two sync scripts are files upstream does not have. The deliberate exception is `CLAUDE.md`, which both sides edit. This ADR exists so that whoever — human or agent — hits that conflict knows it was intended and which side wins.

## What can and cannot conflict

- **`CLAUDE.md` — upstream owns it, the fork has edited it. This is the only file at real risk.**
- `scripts/sync-skills.sh` and `scripts/sync-fork.sh` — **fork-only**; upstream has never had either file, so they cannot conflict no matter how far they evolve. Their headers are the source of truth for their own behaviour.
- `skills/jack/**` — a namespace upstream has never owned. Structurally conflict-free; that is the whole reason it exists (see [skills/jack/README.md](../../skills/jack/README.md)).
- `scripts/link-skills.sh` — upstream's, and **unmodified here on purpose**. Its header states that modifications "will not be approved", so the fork routes around it rather than patching it. Leave it alone; take upstream's version of it every time.

## The six divergences in `CLAUDE.md`

Four are the `skills/jack/` namespace migration (`9346df7`); the fifth is the relinking fix (`69670c9`); the sixth is the pointer to this ADR.

1. **The `skills/jack/` namespace paragraph** — an added paragraph explaining that the namespace is not a bucket and that its buckets sit one level down. No upstream counterpart.
2. **Promotion rule** — upstream's "Skills in `misc/`, `in-progress/`, and `deprecated/` must not appear in either" gains "and anything under `jack/`". Nothing in the namespace is ever promoted to the README or the plugin manifest.
3. **Bucket README rule** — the non-promoted flat-list set gains `jack/personal/` and `jack/deprecated/`, plus a note that `skills/jack/README.md` describes the namespace rather than listing skills.
4. **Docs-page rule** — the no-docs-page set gains "and anything under `jack/`".
5. **Relinking instruction** — upstream says to run `scripts/link-skills.sh`. The fork must not: that script is single-tier and points *both* `~/.claude/skills/<name>` and `~/.agents/skills/<name>` straight at the repo, collapsing the `~/.claude → ~/.agents → repo` indirection this install depends on, and it never prunes. The fork points at `scripts/sync-skills.sh` instead and adds an explicit warning paragraph.

6. **The pointer to this ADR** — a paragraph immediately after divergence 1, stating that `CLAUDE.md` is expected to conflict and that the fork's side wins. It sits there deliberately: divergence 1 says the namespace makes merges conflict-free, which a skimming reader can mistake for "merges here are safe", and this paragraph corrects that on the spot.

Divergences 1–4 are all the same shape: upstream describes five buckets, the fork describes those five plus a namespace. Divergence 5 is the substantive one — following upstream's text on this fork actively breaks the local symlink layout. Divergence 6 is what makes the other five recoverable at all.

## Decision

**On an `upstream/main` conflict in `CLAUDE.md`, the fork's side wins.**

Resolve by **re-applying the fork's changes onto upstream's new text**, not by taking the fork's whole file. Upstream actively edits `CLAUDE.md` for reasons unrelated to any of the five — new bucket rules, new manifest requirements, changed docs conventions — and `--ours` would silently discard all of it. Work through the list above and re-assert each point against whatever upstream now says.

The one that must never be lost is **divergence 5**. Reverting it re-arms the original problem: a file that instructs every agent working in this repo to run a script that breaks the install. Divergences 1–4 are lower stakes; if one is dropped, the symptom is `jack/` skills leaking into the README, `plugin.json`, or `docs/`, which `claude plugin validate . --strict` will not catch because it is a convention rather than a schema rule.

## Invariants this creates

- `CLAUDE.md` is expected to conflict. That is a known cost, accepted when divergence 5 was made, not a sign anything has gone wrong.
- Any *new* fork-local edit to `CLAUDE.md` gets added to the list above in the same commit. A divergence that isn't listed here is one a future merge will quietly revert.
- Prefer putting fork-local behaviour in fork-only files (`scripts/sync-*.sh`, `skills/jack/**`, this ADR). Those cost nothing at merge time. Edit `CLAUDE.md` only when the point has to be visible to an agent that reads only auto-loaded context.
