---
name: fleet
description: Operate Jack's machine fleet from the Mac — reachability/tunnel preflight, wake bigbox via helios WoL API, toggle remote-mode, dispatch agent work to bigbox over SSH/tmux. Use when asked to wake/reach/dispatch work to bigbox, hyperion, or helios, check why a fleet machine is unreachable, or start a remote agent run.
---

# Fleet operations

Design + rationale live in `~/server-kb/fleet.md` (canonical, git-synced).
This skill is the Mac-side operating procedure.

## Machines

| Host | IP | Role | Notes |
|------|-----|------|-------|
| bigbox | 192.168.68.83 | Dev/agent host (also Jack's desktop) | Sleeps; wake on demand. SSH auto-attaches tmux `main`. |
| hyperion | 192.168.68.74 | Prod home server | **Never dev here.** Only fleet piece: ntfy. |
| helios | 192.168.68.56 | DNS, WireGuard hub, WoL API :9090 | Always on. |
| Mac | — | Thin controller | chezmoi + server-kb source of truth. |

SSH aliases (`bigbox`, `hyperion`, `helios`) come from `~/.ssh/config`.
**Gotcha:** bare hostnames don't resolve for non-SSH tools on the Mac (no
LAN DNS search domain) — use the IPs above for curl/ping.

## Preflight — always first

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

## remote-mode (keep bigbox awake for a run)

```bash
ssh bigbox '~/.local/bin/remote-mode on'      # sleep blocked, displays dark
ssh bigbox '~/.local/bin/remote-mode status'
ssh bigbox '~/.local/bin/remote-mode off'     # back to normal idle/suspend
```

Turn it **on** before any run that must outlive the SSH session; **off** when
done. Safety net if forgotten: hypridle's suspend action is a guard that skips
suspend while SSH sessions or `claude` processes exist — but don't rely on it.
Details: `~/server-kb/bigbox/remote-mode.md`.

## Dispatching agent work

- Interactive `ssh bigbox` lands in tmux session `main` — run `claude` there;
  disconnects/lid-closes are free. Non-interactive `ssh bigbox '<cmd>'` and scp
  skip tmux.
- Projects live in `~/code/<project>`; parallel worktrees in `~/code/worktrees/`.
- **Supervised** runs: on the host as `jack`, permission prompts as guardrail.
- **Unattended** (`--dangerously-skip-permissions`): only inside a sandbox or
  devcontainer — never on the bare host.
- Long-run feedback: Claude hooks on bigbox push to `https://ntfy.lan/claude`
  (Stop = run finished, Notification = waiting on input).

## Rules

- hyperion is prod: no project checkouts, no toolchains, no experiments.
- Config changes to bigbox go through chezmoi (source on the Mac), docs
  through server-kb — not ad-hoc edits over SSH.
