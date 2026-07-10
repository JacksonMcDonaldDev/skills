---
name: fleet
description: Operate Jack's machine fleet — reachability/tunnel preflight, wake bigbox via helios WoL API, toggle remote-mode, dispatch agent work to bigbox over SSH/tmux. Host-aware — first identify the current host (Mac controller vs bigbox itself) and skip the steps that don't apply there. Use when asked to wake/reach/dispatch work to bigbox, hyperion, or helios, check why a fleet machine is unreachable, or start a remote agent run.
---

# Fleet operations

Design + rationale live in `~/kb/fleet.md` (the server-kb repo, canonical,
git-synced via the auto-sync hooks — see `~/kb/scripts/`).

## Which host am I on? — always first

Check `hostname` before anything else; the procedure branches on it:

- **`pop-os`** → you are **on bigbox**. Skip preflight and wake entirely (the
  machine you'd be waking is the one you're on). hyperion/helios are on the
  same LAN and hostnames resolve (bigbox uses helios as DNS) — plain
  `ping`/`curl` by name works. See *On bigbox* notes per section below.
- **anything else (Mac)** → thin controller; full procedure applies,
  starting with preflight.

## Machines

| Host | IP | Role | Notes |
|------|-----|------|-------|
| bigbox | 192.168.68.83 | Dev/agent host (also Jack's desktop) | Sleeps; wake on demand. SSH auto-attaches tmux `main`. |
| hyperion | 192.168.68.74 | Prod home server | **Never dev here.** Only fleet piece: ntfy. |
| helios | 192.168.68.56 | DNS, WireGuard hub, WoL API :9090 | Always on. |
| Mac | — | Thin controller | chezmoi + server-kb source of truth. |

SSH aliases (`bigbox`, `hyperion`, `helios`) come from `~/.ssh/config`.
**Mac gotcha:** bare hostnames don't resolve for non-SSH tools on the Mac (no
LAN DNS search domain) — use the IPs above for curl/ping. (Not an issue on
bigbox.)

## Preflight (Mac only)

```bash
nc -z -w 3 192.168.68.56 22 && echo helios-reachable
```

- **helios unreachable** → not on the LAN and the WireGuard tunnel is down.
  Tell Jack to flip the tunnel (WireGuard app on the Mac); nothing else will
  work. Do not diagnose further until helios responds.
- **helios OK but bigbox unreachable** → bigbox is asleep/off. Wake it:

```bash
curl -s -m 5 -X POST http://192.168.68.56:9090/wake/bigbox
# then poll (typically <30 s from suspend):
until ssh -o ConnectTimeout=3 -o BatchMode=yes bigbox true 2>/dev/null; do sleep 3; done
```

**On bigbox:** none of this applies to bigbox itself. If helios or hyperion
seem unreachable *from bigbox*, that's a LAN/service problem, not a tunnel
problem — diagnose directly (`ping helios`, check the service), don't reach
for WireGuard.

## remote-mode (keep bigbox awake for a run)

On bigbox it's a local command; from the Mac, wrap it in ssh:

```bash
~/.local/bin/remote-mode on        # sleep blocked, displays dark (prefix with `ssh bigbox` from the Mac)
~/.local/bin/remote-mode status
~/.local/bin/remote-mode off       # back to normal idle/suspend
```

Turn it **on** before any run that must outlive the session — an SSH session
from the Mac, or a local run Jack starts on bigbox before walking away;
**off** when done. Safety net if forgotten: hypridle's suspend action is a
guard that skips suspend while SSH sessions or `claude` processes exist — but
don't rely on it. Details: `~/kb/bigbox/remote-mode.md`.

## Dispatching agent work

- From the Mac: interactive `ssh bigbox` lands in tmux session `main` — run
  `claude` there; disconnects/lid-closes are free. Non-interactive
  `ssh bigbox '<cmd>'` and scp skip tmux.
- On bigbox: just run `claude` locally; use tmux `main` if the run should
  survive the terminal, and remote-mode if it should survive idle/suspend.
- Projects live in `~/code/<project>`; parallel worktrees in `~/code/worktrees/`.
- **Supervised** runs: on the host as `jack`, permission prompts as guardrail.
- **Unattended** (`--dangerously-skip-permissions`): only inside a sandbox or
  devcontainer — never on the bare host.
- Long-run feedback: Claude hooks on bigbox push to
  `https://ntfy.home.jacksonmcdonald.me/claude` (Stop = run finished,
  Notification = waiting on input). Publisher: `~/.local/bin/claude-ntfy`.
  Note: bigbox must use helios (192.168.68.56) as DNS to resolve that host.

## Rules

- hyperion is prod: no project checkouts, no toolchains, no experiments.
- Config changes to bigbox go through chezmoi (source on the Mac), docs
  through server-kb — not ad-hoc edits over SSH.
