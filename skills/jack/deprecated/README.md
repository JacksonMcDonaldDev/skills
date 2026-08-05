# Deprecated (mine)

Skills I've retired but kept the source of, rather than deleting. Nothing here is
wired into the symlink tree — `scripts/sync-skills.sh` skips any path with a
`deprecated/` segment, so these are readable in the repo and invisible to agents.

Distinct from the top-level [`skills/deprecated/`](../../deprecated/README.md), which is
upstream's and stays empty by policy — Matt deletes retired skills outright and
names the replacement in the changeset.

- **[edit-article](./edit-article/SKILL.md)** — Restructure a draft into dependency-ordered sections, then rewrite each for clarity (max 240 chars per paragraph). Upstream's, retired in `c66bdee` when Matt dropped his `personal/` bucket. Kept because it's the only in-place draft reviser here; its core idea — that information is a DAG and nothing may depend on an ungrounded concept — was rebuilt far more thoroughly as the **Grounding** model in [`writing-shape`](../../in-progress/writing-shape/SKILL.md). Reach for that first.
