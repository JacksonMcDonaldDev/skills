#!/usr/bin/env bash
# sync-skills.sh — sync this fork with git, then reconcile the TWO-TIER symlink layer.
#
# Two-tier (agent-neutral) layout this repo drives:
#   ~/.claude/skills/<name> -> ~/.agents/skills/<name> -> ~/.agents/skills-repo/skills/<cat>/<name>
# (Matt's own scripts/link-skills.sh is single-tier and has no pruning; this is the local replacement.)
#
# Source of truth: every skills/<category>/<name>/SKILL.md in the clone, EXCEPT skills/deprecated/*.
#
# Flags:
#   --pull        git pull --ff-only origin main   (catch up your own fork; safe)
#   --upstream    fetch + merge upstream/main       (Matt's changes; GATED — previews, then asks)
#   --push        git push origin main              (publish to your fork)
#   --yes         skip the upstream-merge confirmation prompt
#   -n|--dry-run  show everything, change nothing
#   -h|--help     this header
#
# Safe by design:
#   * only ever removes SYMLINKS — real dirs (e.g. find-skills from vercel-labs) are never touched
#   * prunes a link only if it's dangling, points at a now-deprecated/removed repo skill, or is ignored
#   * per-machine ignore list at ~/.agents/.skills-ignore (one skill name per line, '#' comments)

set -euo pipefail

REPO="$HOME/.agents/skills-repo"
STORE="$HOME/.agents/skills"
CLAUDE="$HOME/.claude/skills"
IGNORE_FILE="$HOME/.agents/.skills-ignore"

DRY_RUN=0 PULL=0 UPSTREAM=0 PUSH=0 ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    --pull)       PULL=1 ;;
    --upstream)   UPSTREAM=1 ;;
    --push)       PUSH=1 ;;
    --yes)        ASSUME_YES=1 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

run()   { if [ "$DRY_RUN" = 1 ]; then echo "  DRY  $*"; else "$@"; fi; }
git_r() { git -C "$REPO" "$@"; }

[ -d "$REPO/.git" ] || { echo "repo not found: $REPO" >&2; exit 1; }
run mkdir -p "$STORE" "$CLAUDE"

require_clean_tree() {
  if [ -n "$(git_r status --porcelain)" ]; then
    echo "ERROR: working tree in $REPO is dirty — commit or stash first." >&2
    git_r status --short >&2; exit 1
  fi
}

# --- git: catch up your own fork --------------------------------------------
if [ "$PULL" = 1 ]; then
  require_clean_tree
  echo "==> git pull --ff-only origin main"
  run git_r pull --ff-only origin main
fi

# --- git: merge upstream (Matt), GATED --------------------------------------
if [ "$UPSTREAM" = 1 ]; then
  require_clean_tree
  git_r remote get-url upstream >/dev/null 2>&1 || {
    echo "ERROR: no 'upstream' remote. Add it with:" >&2
    echo "  git -C $REPO remote add upstream https://github.com/mattpocock/skills.git" >&2
    exit 1
  }
  echo "==> git fetch upstream"
  git_r fetch upstream --quiet

  incoming=$(git_r rev-list --count HEAD..upstream/main)
  if [ "$incoming" = 0 ]; then
    echo "    already up to date with upstream/main."
  else
    skill_dirs() { git_r ls-tree -r --name-only "$1" -- skills | sed -n 's#/SKILL.md$##p' | sort; }
    going_away=$(comm -23 <(skill_dirs HEAD) <(skill_dirs upstream/main) || true)
    incoming_new=$(comm -13 <(skill_dirs HEAD) <(skill_dirs upstream/main) || true)

    echo
    echo "    $incoming upstream commit(s) incoming."
    [ -n "$incoming_new" ] && { echo "    NEW skills:"; echo "$incoming_new" | sed 's#.*/#      + #'; }
    if [ -n "$going_away" ]; then
      echo "    Paths going away (moved/renamed -> relinked; removed/deprecated -> pruned):"
      while IFS= read -r d; do
        name="${d##*/}"; tgt="$(readlink "$STORE/$name" 2>/dev/null || true)"
        if [ "$tgt" = "../skills-repo/$d" ]; then
          echo "      ! $name   <-- currently wired ($d)"
        else
          echo "        $name   ($d)"
        fi
      done <<< "$going_away"
    fi
    echo

    if [ "$DRY_RUN" = 1 ]; then
      echo "    [DRY RUN] not merging."
    else
      if [ "$ASSUME_YES" != 1 ]; then
        read -r -p "    Merge upstream/main into your fork? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "    aborted."; exit 0; }
      fi
      if ! git_r merge --no-edit upstream/main; then
        git_r merge --abort
        echo "ERROR: merge conflict — aborted, tree restored. Resolve by hand." >&2
        exit 1
      fi
    fi
  fi
fi

# --- ignore list -------------------------------------------------------------
declare -A IGNORED=()
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="${line//[[:space:]]/}"
    [ -n "$line" ] && IGNORED["$line"]=1
  done < "$IGNORE_FILE"
fi

# --- discover skills ---------------------------------------------------------
# ALL_NAMES = every skill name in the repo (all buckets) — drives pruning.
# WANT       = names to actively wire = all skills EXCEPT deprecated/ and ignored.
declare -A ALL_NAMES=() WANT=()
collision=0
while IFS= read -r skillmd; do
  reldir="${skillmd#"$REPO"/}"; reldir="${reldir%/SKILL.md}"   # skills/<cat>/<name>
  name="$(basename "$reldir")"
  ALL_NAMES["$name"]=1
  case "$reldir" in skills/deprecated/*) continue ;; esac      # never wire deprecated
  [ -n "${IGNORED[$name]:-}" ] && continue                     # never wire ignored
  if [ -n "${WANT[$name]:-}" ]; then
    echo "COLLISION: '$name' in ${WANT[$name]} and $reldir" >&2; collision=1
  fi
  WANT["$name"]="$reldir"
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' | sort)
[ "$collision" = 1 ] && { echo "Resolve flat-name collisions first." >&2; exit 1; }

add=0 repoint=0 removed=0 skipped=0 ok=0

# --- pass 1: create / repoint wanted skills ---------------------------------
for name in "${!WANT[@]}"; do
  store_target="../skills-repo/${WANT[$name]}"
  claude_target="../../.agents/skills/$name"

  if [ ! -L "$STORE/$name" ]; then
    [ -e "$STORE/$name" ] && { echo "  WARN $name is a real path in store, leaving alone"; skipped=$((skipped+1)); continue; }
    echo "  +    $name  (-> ${WANT[$name]})"; run ln -sfn "$store_target" "$STORE/$name"; add=$((add+1))
  elif [ "$(readlink "$STORE/$name")" != "$store_target" ]; then
    echo "  ~    $name  (repoint -> ${WANT[$name]})"; run ln -sfn "$store_target" "$STORE/$name"; repoint=$((repoint+1))
  else ok=$((ok+1)); fi

  [ "$(readlink "$CLAUDE/$name" 2>/dev/null || true)" != "$claude_target" ] && run ln -sfn "$claude_target" "$CLAUDE/$name"
done

# --- pass 2: prune dangling / deprecated / removed / ignored symlinks -------
# Never touches real dirs (find-skills) or symlinks pointing at skills we don't manage.
prune_dir() {
  for entry in "$1"/*; do
    [ -L "$entry" ] || continue
    base="$(basename "$entry")"
    if [ ! -e "$entry" ] \
       || { [ -n "${ALL_NAMES[$base]:-}" ] && [ -z "${WANT[$base]:-}" ]; } \
       || [ -n "${IGNORED[$base]:-}" ]; then
      echo "  -    $base  (${1/#$HOME/\~})"; run rm -f "$entry"; removed=$((removed+1))
    fi
  done
}
prune_dir "$STORE"
prune_dir "$CLAUDE"

# --- git: publish ------------------------------------------------------------
if [ "$PUSH" = 1 ]; then
  echo "==> git push origin main"
  run git_r push origin main
fi

echo
echo "links: added=$add repointed=$repoint removed=$removed unchanged=$ok skipped=$skipped$([ "$DRY_RUN" = 1 ] && echo '  [DRY RUN]')"
