# jack/

My own skills, namespaced away from upstream's buckets.

This is a **namespace, not a bucket** — the buckets are one level down. Everything
under here is mine; everything outside it is Matt's. That's the whole point: before
this split, my skills and his sat together in `skills/personal/`, and telling them
apart took a `git log`. Two of them (`edit-article`, `obsidian-vault`) turned out to
be his after months of looking like mine.

The second benefit is merge hygiene. My commits now touch only paths upstream has
never owned, so my side of an `upstream/main` merge is structurally conflict-free.

| Bucket | Wired into the symlink tree? | Contents |
|---|---|---|
| [`personal/`](./personal/README.md) | yes | My active skills |
| [`deprecated/`](./deprecated/README.md) | no | Retired, kept for reference |

Nothing under `jack/` is promoted: no entry in the top-level `README.md`, none in
`.claude-plugin/plugin.json`, no docs page. The plugin ships only `engineering/`
and `productivity/`.

Both `scripts/sync-skills.sh` and upstream's `scripts/link-skills.sh` find skills by
walking for `SKILL.md` at any depth, so the extra level needs no special handling.
