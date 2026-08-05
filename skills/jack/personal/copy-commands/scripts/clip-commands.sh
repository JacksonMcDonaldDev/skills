#!/usr/bin/env bash
# clip-commands.sh — copy suggested shell commands to the Wayland clipboard.
# Reads NUL-separated commands on stdin so multi-line commands stay intact.
#
# Usage:
#   printf '%s\0' "$c1" "$c2" | clip-commands.sh block        # one clipboard entry
#   printf '%s\0' "$c1" "$c2" | clip-commands.sh seq [delay]  # one entry per command
set -euo pipefail

mode="${1:-block}"
delay="${2:-0.4}"

command -v wl-copy >/dev/null \
  || { echo "clip-commands: wl-copy not found (need wl-clipboard on Wayland)" >&2; exit 1; }
[ -n "${WAYLAND_DISPLAY:-}" ] \
  || echo "clip-commands: warning: WAYLAND_DISPLAY unset — wl-copy may fail" >&2

mapfile -d '' -t cmds
# drop a possible trailing empty record from printf '%s\0'
[ "${#cmds[@]}" -gt 0 ] && [ -z "${cmds[-1]}" ] && unset 'cmds[-1]'
[ "${#cmds[@]}" -gt 0 ] || { echo "clip-commands: no commands on stdin" >&2; exit 1; }

case "$mode" in
  block)
    # join with newlines, NO trailing newline so a paste won't auto-run the last cmd
    out=""
    for i in "${!cmds[@]}"; do
      [ "$i" -gt 0 ] && out+=$'\n'
      out+="${cmds[$i]}"
    done
    printf '%s' "$out" | wl-copy
    echo "clip-commands: copied ${#cmds[@]} command(s) as one block."
    ;;
  seq|sequential)
    for cmd in "${cmds[@]}"; do
      printf '%s' "$cmd" | wl-copy
      sleep "$delay"   # let cliphist's wl-paste watcher record this entry
    done
    echo "clip-commands: copied ${#cmds[@]} command(s) individually into cliphist (newest = last)."
    ;;
  *)
    echo "clip-commands: unknown mode '$mode' (use block|seq)" >&2
    exit 1
    ;;
esac
