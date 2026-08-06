Skills are organized into bucket folders under `skills/`:

- `engineering/` — daily code work
- `productivity/` — daily non-code workflow tools
- `misc/` — kept around but rarely used, not promoted
- `in-progress/` — beta: public on purpose, feedback wanted, not shipped in the plugin
- `deprecated/` — no longer used

My own skills are namespaced under `skills/jack/`, which is a **namespace, not a bucket** — its buckets sit one level down: `jack/personal/` (mine, active) and `jack/deprecated/` (mine, retired). Everything under `jack/` is fork-local and never promoted. Keeping it off upstream's paths is what makes my side of an `upstream/main` merge conflict-free; see [skills/jack/README.md](./skills/jack/README.md).

That applies to `skills/jack/` only. **This file itself is the one place the fork deliberately diverges from upstream, so it is expected to conflict on an `upstream/main` merge — keep the fork's side.** Re-apply the fork's changes onto upstream's new text rather than taking the whole file; [.agents/adr/0003-fork-local-divergences-from-upstream.md](./.agents/adr/0003-fork-local-divergences-from-upstream.md) lists each divergence and which one must never be lost.

Every skill in `engineering/` or `productivity/` (the **promoted** buckets) must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`'s `skills` array (the Claude Code plugin ships exactly the promoted set). Skills in `misc/`, `in-progress/`, `deprecated/`, and anything under `jack/` must not appear in either.

Install commands are copied verbatim from [.agents/install-block.md](./.agents/install-block.md). `.claude-plugin/marketplace.json` makes the repo its own single-plugin marketplace — a fallback the install block explains, not the documented route. Run `claude plugin validate . --strict` after touching either manifest. Why a Claude plugin but not (yet) a Codex one lives in [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md).

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`. The promoted buckets' `README.md`s and the top-level `README.md` group entries into **User-invoked** and **Model-invoked**; non-promoted bucket `README.md`s (`misc/`, `in-progress/`, `jack/personal/`, `jack/deprecated/`) use a flat list. `skills/jack/README.md` describes the namespace itself rather than listing skills.

Skills in `engineering/` and `productivity/` also have a human-facing docs page at `docs/<bucket>/<skill-name>.md` (the docs tree mirrors those two bucket folders under `skills/`). The published URL is `https://aihero.dev/skills-<skill-name>` regardless of bucket — the docs path is repo organisation only. When you add, rename, or change the behaviour of a skill in `engineering/` or `productivity/`, create or re-sync its docs page following [.agents/writing-docs.md](./.agents/writing-docs.md). A finished page carries four sections — **What it does**, **When to reach for it**, **Common questions**, **It's working if** — and `writing-docs.md` holds the template, the section order, and where to hunt for the questions. Skills in the non-promoted buckets (`misc/`, `in-progress/`, `deprecated/`, and anything under `jack/`) get **no** docs page.

Every `SKILL.md` is either user-invoked (`disable-model-invocation: true` plus `policy.allow_implicit_invocation: false` in `agents/openai.yaml`, reachable only by the human) or model-invoked (model- or user-reachable). See [.agents/invocation.md](./.agents/invocation.md).

[`ask-matt`](./skills/engineering/ask-matt/SKILL.md) is the router that maps every user-reachable skill and how they relate. The same trigger that re-syncs a docs page applies to it: whenever you add, rename, remove, or change how a user-reachable skill fits the flows, re-read `ask-matt`'s `SKILL.md` and update it so the map stays accurate — a new skill it never mentions, or a stale one it still routes to, is a router that lies.

To (re)link every skill into the local harness skill directories (`~/.claude/skills`, `~/.agents/skills`), run `scripts/sync-skills.sh` — on macOS as `/opt/homebrew/bin/bash ./scripts/sync-skills.sh`, since it needs bash 4+. Each entry is a symlink into this repo, so a `git pull` keeps installed skills current; re-run the script after adding, removing, or renaming a skill. It also prunes links that are dangling, deprecated, or ignored, and `--dry-run` previews the whole reconciliation.

**Do not run `scripts/link-skills.sh` on this fork.** It is upstream's, it is single-tier, and it points *both* `~/.claude/skills/<name>` and `~/.agents/skills/<name>` straight at the repo — collapsing the `~/.claude → ~/.agents → repo` indirection this install depends on. It also never prunes. `sync-skills.sh` is the fork-local replacement; its header explains the layout.
