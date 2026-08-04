#!/usr/bin/env bash
# skills-sync.sh — one command for the whole loop, on either machine:
#
#   fetch upstream -> merge -> fetch origin -> merge -> push origin -> sync-skills.sh
#
# Flags:
#   -n|--dry-run  fetch, preview every merge, change nothing else
#   --no-push     merge and relink for real, but don't publish to origin
#   -h|--help     this header
#
# Why it exists:
#   * ALWAYS fetches before counting ahead/behind. Stale refs are the bug this
#     script is for — a stale origin/main once read "180 ahead", and bigbox read
#     "0 behind" while it was really 28 behind. That includes a second fetch
#     immediately before the push, since bigbox can push while we're merging.
#   * Every merge is previewed with `git merge-tree --write-tree` first. A
#     conflict stops the run before that merge has been applied.
#   * Never force-pushes. bigbox pushes to this fork too.
#   * Never stashes. A dirty tree stops the run instead.
#   * Re-execs under bash 4+ (macOS /bin/bash is 3.2.57 and sync-skills.sh needs
#     `declare -A`), so plain `./scripts/skills-sync.sh` works on both hosts.
#
# Merging is this script's job; sync-skills.sh is called at the end for symlinks
# only, with none of its git flags. It is called even when the run fails partway,
# so long as something was merged — otherwise a failed push would leave newly
# merged skills committed but unwired.
#
# ASSUMPTIONS — three open questions were unanswered when this was written. The
# conservative answer was taken in each case; change it here if it's wrong.
#   1. MANUAL ONLY. No launchd/systemd timer is installed or implied. The script
#      assumes a human is watching the output, which is why it may push at all.
#   2. CONFLICT MEANS STOP. On conflict it reports the paths and stops. It never
#      auto-resolves and never leaves you in a conflicted worktree. Note it says
#      nothing about *earlier* steps: if upstream merges cleanly and origin then
#      conflicts, that upstream merge commit stays — it is committed, not lost,
#      and the run says so before it stops.
#   3. in-progress/ SKILLS ARE NOT PRUNED. sync-skills.sh wires them exactly as
#      it does today; nothing here changes that.
#
# One nuance on "dirty": tracked changes (staged or not) stop the run. Untracked
# files only print a note — otherwise this script would refuse to run until it
# was itself committed, and git already refuses any merge that would clobber an
# untracked file.

set -euo pipefail

# --- bash 4+ -----------------------------------------------------------------
# bigbox's bash is 5.2 and falls straight through. macOS needs the Homebrew one.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash; do
    [ -x "$candidate" ] || continue
    [ "$("$candidate" -c 'echo ${BASH_VERSINFO[0]:-0}' 2>/dev/null || echo 0)" -ge 4 ] || continue
    exec "$candidate" "$0" "$@"
  done
  echo "ERROR: need bash 4+ (running ${BASH_VERSION:-unknown}) — sync-skills.sh uses 'declare -A'." >&2
  echo "  install one with:  brew install bash" >&2
  exit 1
fi

DRY_RUN=0 NO_PUSH=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    --no-push)    NO_PUSH=1 ;;
    # only the leading block, not every '# ---' banner further down
    -h|--help)    awk 'NR==1 && /^#!/ {next} /^#/ {sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BRANCH=main
MERGED=() PREVIEWED=() PUSHED=0 PUSH_FAILED=0 SYMLINKS_DONE=0

git_r() { git -C "$REPO" "$@"; }

[ -d "$REPO/.git" ] || { echo "repo not found: $REPO" >&2; exit 1; }

# `merge-tree --write-tree` landed in git 2.38, but `--name-only` (used below to
# list the conflicting paths) only in 2.40. Gate on the higher of the two.
gv="$(git --version | awk '{print $3}')"
gv_major="${gv%%.*}"; gv_minor="${gv#*.}"; gv_minor="${gv_minor%%.*}"
if [ "$gv_major" -lt 2 ] || { [ "$gv_major" -eq 2 ] && [ "$gv_minor" -lt 40 ]; }; then
  echo "ERROR: git $gv is too old — 'merge-tree --write-tree --name-only' needs 2.40+." >&2
  exit 1
fi

current_branch="$(git_r rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$BRANCH" ]; then
  echo "ERROR: $REPO is on '$current_branch', not '$BRANCH' — switch back before syncing." >&2
  exit 1
fi

GITDIR="$(git_r rev-parse --absolute-git-dir)"
if [ -e "$GITDIR/MERGE_HEAD" ] || [ -e "$GITDIR/rebase-merge" ] || [ -e "$GITDIR/rebase-apply" ]; then
  echo "ERROR: $REPO is mid-merge/rebase — finish or abort it first." >&2
  exit 1
fi

# --- refuse a dirty tree (never stash) ---------------------------------------
if [ -n "$(git_r status --porcelain --untracked-files=no)" ]; then
  echo "ERROR: working tree in $REPO has uncommitted changes — commit them first." >&2
  echo "       nothing is stashed; this script will not touch your work." >&2
  git_r status --short >&2
  exit 1
fi
untracked="$(git_r ls-files --others --exclude-standard)"
if [ -n "$untracked" ]; then
  echo "note: untracked file(s) in the repo, continuing anyway:"
  echo "$untracked" | sed 's/^/      ? /'
fi

# --- symlinks ----------------------------------------------------------------
# Called at the end of a good run, and from the failure paths once anything has
# been merged. Runs at most once.
#
# sync-skills.sh hardcodes $HOME/.agents/skills-repo. From any other clone it
# would reconcile the real install against THIS clone's merges, so skip it —
# don't merge one clone and relink another.
sync_symlinks() {
  [ "$SYMLINKS_DONE" = 0 ] || return 0
  SYMLINKS_DONE=1

  if [ "$REPO" != "$HOME/.agents/skills-repo" ]; then
    echo "note: skipping sync-skills.sh — it reconciles \$HOME/.agents/skills-repo, not $REPO"
    return 0
  fi

  echo "==> scripts/sync-skills.sh"
  if [ "$DRY_RUN" = 1 ]; then
    "$BASH" "$REPO/scripts/sync-skills.sh" --dry-run
  else
    "$BASH" "$REPO/scripts/sync-skills.sh"
  fi
}

# --- fetch + merge one remote ------------------------------------------------
merge_remote() {
  local remote="$1" ref="$1/$BRANCH" behind ahead out err status tmp_err

  git_r remote get-url "$remote" >/dev/null 2>&1 || {
    echo "ERROR: no '$remote' remote in $REPO." >&2
    exit 1
  }

  echo "==> git fetch $remote"
  git_r fetch "$remote" --quiet     # ALWAYS — a cached ref is how we got wrong counts

  behind="$(git_r rev-list --count "HEAD..$ref")"
  ahead="$(git_r rev-list --count "$ref..HEAD")"
  echo "    $ref: $behind to merge, $ahead local commit(s) it doesn't have"

  if [ "$behind" = 0 ]; then
    echo "    already up to date."
    return 0
  fi

  # Preview. 0 = clean, 1 = conflicts, anything else = git itself errored.
  # Keep stderr out of $out: the conflict list is parsed by position below, and
  # a stray git warning folded into it would read as a conflicting path.
  tmp_err="$(mktemp)"
  out="$(git_r merge-tree --write-tree --name-only HEAD "$ref" 2>"$tmp_err")" && status=0 || status=$?
  err="$(cat "$tmp_err")"; rm -f "$tmp_err"

  if [ "$status" != 0 ]; then
    echo >&2
    if [ "$status" = 1 ]; then
      echo "ERROR: merging $ref would conflict — that merge has not been started." >&2
      echo "    conflicting path(s):" >&2
      echo "$out" | tail -n +2 | sed '/^$/,$d' | sed 's/^/      /' >&2
    else
      echo "ERROR: could not preview the merge of $ref — that merge has not been started." >&2
      [ -n "$err" ] && echo "$err" | sed 's/^/      /' >&2
      [ -n "$out" ] && echo "$out" | sed 's/^/      /' >&2
    fi
    echo >&2
    echo "    Both machines edit the skills in this repo, so resolve it by hand:" >&2
    echo "      git -C $REPO merge $ref" >&2
    stop_after_partial_merge
    exit 1
  fi

  echo "    preview clean ($behind commit(s))."
  if [ "$DRY_RUN" = 1 ]; then
    echo "  DRY  git merge --no-edit $ref"
    PREVIEWED+=("$ref")
    return 0
  fi

  # Belt and braces: the preview said clean, but git can still refuse (e.g. an
  # incoming file that would clobber an untracked one).
  if ! git_r merge --no-edit "$ref"; then
    if [ -e "$GITDIR/MERGE_HEAD" ]; then
      git_r merge --abort
      echo "ERROR: merge of $ref conflicted — aborted, tree restored." >&2
    else
      echo "ERROR: merge of $ref would not start (see git's message above) — that merge has not been applied." >&2
    fi
    stop_after_partial_merge
    exit 1
  fi
  MERGED+=("$ref")
}

# An earlier remote may already have merged. Those commits are in HEAD, so the
# symlink tree is stale until sync-skills.sh runs — do it before giving up.
stop_after_partial_merge() {
  [ "${#MERGED[@]}" != 0 ] || return 0
  echo >&2
  echo "    ${#MERGED[@]} earlier merge(s) are already committed (${MERGED[*]})." >&2
  echo "    Reconciling symlinks for those before stopping." >&2
  sync_symlinks
}

# --- upstream (Matt) then origin (the fork both machines push to) ------------
merge_remote upstream
merge_remote origin

if [ "$DRY_RUN" = 1 ] && [ "${#PREVIEWED[@]}" -gt 1 ]; then
  echo
  echo "    [DRY RUN] both previews were taken against the current HEAD; applying the"
  echo "    upstream merge for real could change what the origin merge looks like."
fi

# --- publish -----------------------------------------------------------------
if [ "$NO_PUSH" = 1 ]; then
  ahead="$(git_r rev-list --count "origin/$BRANCH..HEAD")"
  echo "==> --no-push: skipping push ($ahead commit(s) ahead of origin/$BRANCH)."
elif [ "$DRY_RUN" = 1 ]; then
  if [ "${#PREVIEWED[@]}" != 0 ]; then
    # nothing was merged, so the current count isn't what a real run would push
    echo "  DRY  git push origin $BRANCH   (whatever the ${#PREVIEWED[@]} merge(s) above leave ahead)"
  else
    ahead="$(git_r rev-list --count "origin/$BRANCH..HEAD")"
    if [ "$ahead" = 0 ]; then
      echo "==> nothing to push."
    else
      echo "  DRY  git push origin $BRANCH   ($ahead commit(s))"
    fi
  fi
else
  # Re-fetch. origin was last fetched before the merges above, and bigbox can
  # push at any time — counting against that older ref would make the check
  # below unable to ever fire.
  echo "==> git fetch origin   (re-check before pushing)"
  git_r fetch origin --quiet
  ahead="$(git_r rev-list --count "origin/$BRANCH..HEAD")"
  behind="$(git_r rev-list --count "HEAD..origin/$BRANCH")"

  if [ "$ahead" = 0 ]; then
    echo "==> nothing to push."
  elif [ "$behind" != 0 ]; then
    echo "WARN: origin/$BRANCH moved during this run ($behind new commit(s)) — not pushing." >&2
    echo "      re-run to merge them first." >&2
    PUSH_FAILED=1
  else
    echo "==> git push origin $BRANCH   ($ahead commit(s))"
    if git_r push origin "$BRANCH"; then   # never -f: that would delete bigbox's work
      PUSHED=1
    else
      echo "WARN: push failed — the $ahead commit(s) above are committed locally, not published." >&2
      echo "      symlinks are still reconciled below; re-run once it's fixed." >&2
      PUSH_FAILED=1
    fi
  fi
fi

sync_symlinks

echo
if [ "$DRY_RUN" = 1 ]; then
  echo "sync: would merge=$([ "${#PREVIEWED[@]}" = 0 ] && echo none || echo "${PREVIEWED[*]}")  [DRY RUN]"
else
  echo "sync: merged=$([ "${#MERGED[@]}" = 0 ] && echo none || echo "${MERGED[*]}") pushed=$([ "$PUSHED" = 1 ] && echo yes || echo no)"
fi

[ "$PUSH_FAILED" = 0 ] || exit 1
