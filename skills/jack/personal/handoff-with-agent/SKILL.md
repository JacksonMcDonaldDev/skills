---
name: handoff-with-agent
description: Write a handoff document, then open a new tab running a fresh agent on it.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Hand the current work to an agent that **cold-starts** — a new session sharing no memory of this conversation. The handoff file is the only channel between the two, so it has to stand on its own. The new session opens visibly and ready to talk to; nothing is left for the user to attach to.

## 1. Write the handoff file

`~/.agents/skills/handoff/SKILL.md` is the single source of truth for what a handoff document contains. Read it and apply its rules. (Fall back to `~/.claude/skills/handoff/SKILL.md` if that path is missing.)

Save to the OS temp directory as `handoff-<slug>.md`, where `<slug>` is two to four kebab-case words naming the work.

Write for the cold start: the next agent opens this file and has nothing else. Every path it must read, command it must run, and decision already settled belongs in the file, or behind a path it can follow.

Separate what is **settled** from what is **open**. Anything the user has not actually chosen — the approach, the tool, the file to edit — goes in the file as a question for them to answer, phrased so the next agent asks rather than assumes. State which facts you verified on the machine, so the next agent knows what to re-check.

Done when the file is on disk and you have its absolute path.

## 2. Open a session on it

Seed the new session with a short prompt pointing at the file, so the document travels on disk rather than through a shell argument:

    Read <absolute-path> and continue that work.

Build the agent command from the running harness — `CLAUDECODE=1` means Claude Code (`claude "<seed prompt>"`); `AI_AGENT` names the harness and version wherever it is set. Open in the directory the current work lives in.

Launch it with the first of these that is available:

- **A cmux tab** — when `cmux ping` answers `PONG`. Create the tab, then drive the command into it, taking `<surface>` from the create call's output (`OK surface:N pane:N workspace:N`):

      cmux new-surface --type terminal --working-directory "<dir>" --focus true
      cmux send --surface <surface> "<agent command>"
      cmux send-key --surface <surface> enter

- **A new terminal window** — identify the terminal from `$TERM_PROGRAM` and use its own "run a command" flag. For Ghostty on macOS, whose CLI binary refuses to launch the emulator directly:

      open -na Ghostty.app --args --working-directory="<dir>" -e <agent command>

- **Neither** — leave the launch to the user and go to step 3.

Verify the agent actually came up rather than trusting the exit code: `cmux read-screen --surface <surface>` shows what the new tab is displaying.

## 3. Report

Give the user the file path, and where the new agent is running — or, where nothing launched, the exact command that starts it.

Done when a fresh agent is up and visible against the file, or the user holds both the path and a command that gets there.

## Note on `claude` inside cmux

Inside a cmux session, `claude` on `$PATH` is a wrapper shim that treats subcommands (`logs`, `stop`, …) as prompts and answers them conversationally instead of running them. Reach for `/opt/homebrew/bin/claude` when a subcommand has to do real work.
