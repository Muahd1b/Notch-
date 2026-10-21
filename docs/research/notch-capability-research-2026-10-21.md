# Notch- Capability Research — 2026-10-21

Four parallel research passes (local workflows, GitHub/org activity, web + macOS API feasibility,
agent-fleet signals) plus live `gh` verification. Goal: decide what the notch should do next,
grounded in evidence rather than feature envy.

Sources:
- `/tmp/notch-research-workflows.md` — local machine scan (automations, zsh history, herdr, launchd, Obsidian).
- `/tmp/notch-research-github.md` — GitHub/CI/triage shape, verified with authenticated `gh`.
- `/tmp/notch-research-web.md` — competitor matrix, Apple API capability limits, glanceable UX constraints.
- `/tmp/notch-research-agents.md` — agent-fleet data inventory (Codex/Claude/OpenCode stores).

---

## 1. What the evidence says

**The notch is currently decorative relative to how the day actually runs.** The repeated loop is:
which agent is running → which terminal/tmux session → which host → which port → is main green →
did the automation run. Every one of those answers already exists on disk or in a local socket.

Hard numbers:

| Signal | Value | Source |
|---|---|---|
| Codex automations on disk | 16 (7 active, 9 paused), 2 with passed target dates | `~/.codex/automations/*/automation.toml` |
| Agent session stores | Codex rollouts, Claude transcripts, OpenCode `session_v2`, Ollama `/api/ps` | already parsed by `AgentSessionScanner` |
| Org repos | 33 in `kernscale` | `gh api orgs/kernscale/repos` |
| Open PRs | 11 across 5 repos | `gh pr list` per repo |
| `needs-triage` issues | 30 | `gh search issues` |
| Red main | `Kernscale-Operations` — Container security failure (2026-10-19) | `gh run list --branch main` |
| Backup health | silent lock contention, checked monthly | `~/Library/Logs/Kernscale Backup/check.log` |
| tmux/ssh churn | `ssh kernscale2-*`, `tmux attach -t server1|agents2|ops2|prod2` | `~/.zsh_history` |

**Market gap:** the largest notch app's most-upvoted open feature request is Claude Code / agent
session monitoring (Boring Notch #951). Nobody ships an operator-grade agent surface. That is
exactly where this app already has working adapters — the differentiator is one release away.

**Hard limits (do not design around these):**
- ActivityKit Live Activities are iOS/iPadOS only — notch "Live Activities" are hand-rolled SwiftUI.
- WidgetKit cannot render inside our panel.
- Reading other apps' notifications, Bluetooth headset battery: no public API.
- Sandboxed subprocess spawning blocks `osascript`/`git`/`ps` — this app is Developer-ID, non-sandboxed. Fine for personal use, incompatible with App Store distribution.

---

## 2. Merged, ranked feature list

Ranked by (value for a solo operator) ÷ effort, with cross-source agreement noted.

| # | Feature | What it shows | Data source | Effort | Perms | Agreed by |
|---|---|---|---|---|---|---|
| 1 | **Agent attention queue** | One row per live session: provider, repo, state (working / waiting on you / done / errored), age. Badge in the closed notch. | existing `AgentSessionScanner` + `ps` sweep; add `waiting` detection | S | none | web #1, workflows #1, fleet |
| 2 | **Automation ledger** | `7 active · 9 paused · 2 overdue`; list with next run + last run; tap opens the automation's memory. | `~/.codex/automations/*/automation.toml` (`name`, `status`, `rrule`, `cwds`) + `memory.md` mtime | S | none | workflows #2 |
| 3 | **Dev status strip** | Repo chip (branch/dirty/ahead-behind) + PR/CI badge + service health dot. | `git status --porcelain=v2`, `gh run list`, existing probes | M | none (gh token) | web #2, github #1 |
| 4 | **Session & port atlas** | tmux sessions → host → repo → listening port, in one grid. | `tmux list-sessions`, `~/.ssh/config`, `lsof -iTCP -sTCP:LISTEN` | M | none | workflows #3 |
| 5 | **Triage inbox** | 30 `needs-triage` issues + 11 open PRs, grouped by repo, red-CI first. | `gh issue list --label needs-triage`, `gh pr list --json statusCheckRollup` | S/M | none (gh token) | github #2 |
| 6 | **Quick capture inbox** | Global hotkey → one line → Obsidian `imports/` note. | Carbon `RegisterEventHotKey` + file append | S | none | web #3 |
| 7 | **Backup freshness tile** | Last backup / last check age, lock-contention flag. | `~/Library/Logs/Kernscale Backup/*.log`, restic snapshot mtime | S | none | workflows #5 |
| 8 | **Clipboard shelf** | Last N clipboard items, type-filtered, click to re-copy; honor concealed/transient types. | `NSPasteboard.changeCount` | S | none | web #3 |
| 9 | **Pinned sneak peek** | One chosen chip always visible instead of a transient reveal. | existing state + layout config | S | none | web #1 |
| 10 | **Local drift guard** | Unpushed `codex/*` branches, repos behind origin, client sites missing from the portfolio registry. | local `git` only, zero auth | S | none | github #3 |
| 11 | **Daily briefing one-liner** | Issue counts + delta since yesterday + "first move:" line from the 05:30 automation. | latest `snapshot-*.json` + `memory.md` tail | S | none | workflows #3 |
| 12 | **Stale-target watchdog** | Automations whose rrule target date has passed with no completion. | `automation.toml` rrule vs now | S | none | workflows #6 |
| 13 | **Meeting-vs-agent conflict** | "Call in 8 min, 2 agents mid-run" + call timer while a call app is frontmost. | EventKit + `NSWorkspace` + CoreAudio device-in-use | S | calendar (already) | workflows #23, web #2 |
| 14 | **Focus auto-context** | Timer labels itself with the active repo/agent session; auto-start on deep-work calendar events. | `NSWorkspace.frontmostApplication` + EventKit | S | calendar (already) | workflows #8, web #11 |
| 15 | **Token/spend meter** | Today's tokens per provider, budget bar, from data already parsed. | Codex `token_count`, Claude usage, OpenCode `tokens_*` | M | none | workflows #20, web #17 |
| 16 | **AppIntents surface** | "Start focus", "log habit", "show agents" callable from Shortcuts/Raycast/Siri. | `AppIntents` + `AppShortcutsProvider` | S | none | web #15 |

Explicitly **not** next: system HUD replacement, push-to-talk transcription, screen-recording OCR.
Each buys a scary permission or a large bug surface (media-key event taps are the top bug source in
Boring Notch) for value that does not differentiate.

---

## 3. Top three to build

**1. Agent attention queue (S).** *Shipped 2026-10-21:* statuses are now
`working / needs review / failed / idle` derived from Codex `task_started|task_complete|turn_aborted`,
Claude `stop_reason`, and OpenCode last message role; guardian/subagent rollouts are filtered out and
Codex titles come from `session_index.jsonl`. Codex plan usage (`rate_limits.primary.used_percent`)
shows in the detail card. Remaining: herdr `blocked` and `.orchestration` `awaiting_ack` feeding the
same rail.

**2. Automation ledger (S).** Pure file reads, zero permissions, and it surfaces real forgotten work
(two automations past their target date). Closed: thin progress bar under the notch, green→amber by
overdue count. Open: 16 rows with state chips.

**3. Dev status strip (M).** Repo chip + PR/CI badge + service health, all through one coalesced
scheduler tick. Live evidence justifies it: one red main, 11 open PRs, 30 triage issues — all
invisible unless the terminal is open.

---

## 4. Agent fleet: what is actually observable

From `/tmp/notch-research-agents.md`:

- **Codex** rollouts carry a real turn state machine — `task_started` / `task_complete` / `turn_aborted` — plus `rate_limits.primary.used_percent` and `session_index.jsonl` human thread names.
- **Claude** transcripts carry `gitBranch` and `stop_reason`, so a finished turn is detectable.
- **OpenCode** has `message.data.role` (last role = turn state) and `session_inbox` for queued prompts; `session_pending` was empty on this machine, so it is not a reliable "waiting" signal.
- **herdr** (`~/.config/herdr/herdr.sock`) is the real control plane and the **only** source with an explicit `blocked` agent state.
- `.orchestration/runs/<id>/state.yaml` has `phase: awaiting_ack` — the ack gate is a first-class "needs you" signal.

**Live defect found and fixed:** 7 of 8 recent Codex rollouts were `thread_source: "guardian_review"`
subagents. The agents page was listing machine review threads as if they were the user's work.

## 5. Constraints for anything built here

- One scheduler tick for all polling; `NSBackgroundActivityScheduler`, not `Timer`.
- Pause on screen sleep and session resign-active; back off on battery.
- Never spawn a shell more than once every few seconds; cache `gh` responses with ETags.
- Strip shows state, not content: colour + glyph + one short string, max 3 items.
- `NSPanel` stays `.nonactivatingPanel`; never steal key focus on a timer.
- Sleep/wake and display reconfiguration are the incumbents' top bug class — the anchoring work in
  `ShellWindowController` is the right foundation, keep hardening it.
