---
name: copy-commands
description: Copy the shell commands Claude just suggested into the Wayland clipboard so the user can paste them into a separate terminal — without Claude Code's hard-wrap line-break artifacts. Copies either as one block, or one command at a time into cliphist history for separate pasting. Use when the user says "copy that command", "copy those commands", "copy to clipboard to run", "/copy-commands", or wants suggested commands moved to the clipboard.
---

# copy-commands

Copies commands Claude recently suggested into the clipboard via `wl-copy`, bypassing
the rendered-TUI selection (which injects hard newlines). Host: bigbox — kitty +
wl-clipboard + cliphist (`Super+Alt+V` opens history).

## Steps

1. **Collect the commands.** Scan recent assistant turns for shell commands suggested
   for the user to run in a *separate terminal* (fenced `sh`/`bash` blocks, inline
   `wl-copy ...`, install/run commands). Take the source text from the conversation —
   never re-type from the wrapped on-screen rendering. If it's ambiguous which to
   include, list the candidates and confirm before copying.

2. **Pick the mode** (from the skill args, else ask):
   - `block` (default) — all commands in ONE clipboard entry, newline-separated.
     Paste once to run the lot.
   - `seq` — each command copied separately so cliphist keeps one history entry per
     command; user pulls them individually with `Super+Alt+V`.

3. **Copy** with the bundled script. Pass commands NUL-separated on stdin so
   multi-line commands stay intact:
   ```sh
   printf '%s\0' "$cmd1" "$cmd2" "$cmd3" | \
     ~/.claude/skills/copy-commands/scripts/clip-commands.sh block
   ```
   Swap `block` for `seq` for one-at-a-time mode. Optional 2nd arg to `seq` overrides
   the inter-copy delay (default `0.4`s — the breathing room cliphist's watcher needs
   to register each entry).

4. **Report** what landed on the clipboard: list the commands and the mode. For `seq`,
   remind the user cliphist is newest-first (the last command is on top), reached via
   `Super+Alt+V`.

## Notes

- No trailing newline is added, so a pasted single command does NOT auto-execute — the
  user presses Enter. In `block` mode the final command also has no trailing newline.
- `seq` copies in the given order; cliphist shows newest-first. Pass commands in run
  order and tell the user the top history entry is the *last* step.
- If `wl-copy` is missing or not on Wayland, the script errors — say so plainly rather
  than falling back to scraping the terminal.
