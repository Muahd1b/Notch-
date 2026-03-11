# Notch- Integration Research

Date: March 9, 2026
Status: Active reference

## Purpose

This document evaluates the requested `Notch-` integrations:

- Apple Calendar
- Codex
- Claude Code
- OpenClaw
- running local hosts
- habits with Notion
- current learnings
- Pomodoro / time tracking
- Boring Notch-style UI and haptics

For each area, this document covers:

- best integration path
- data availability
- permissions / auth
- feasibility
- risk
- recommended V1 approach

## Integration Summary

| Integration | Best path | Feasibility | Risk | V1 recommendation |
| --- | --- | --- | --- | --- |
| Apple Calendar | EventKit | High | Low | Ship in V1 |
| Codex | local observer + optional wrapper | Medium | Medium | Ship in V1 with observer adapter |
| Claude Code | local observer + optional hooks | High | Medium | Ship in V1 |
| OpenClaw | Gateway/session adapter | High if user runs local gateway | Medium | Ship in V1 as configurable adapter |
| Local hosts | configured probes + optional process hints | High | Medium | Ship in V1 |
| Habits / Notion | local model + Notion sync | High | Low | Ship in V1 |
| Current learnings | local model + Notion learning log | High | Low | Ship in V1 |
| Pomodoro / time tracking | first-party local engine | High | Low | Ship in V1 |
| Boring Notch-grade UI/haptics | AppKit panel + SwiftUI + NSHapticFeedbackManager | High | Low | Ship in V1 |

## 1. Boring Notch-Style UI and Haptics

### Goal

Recreate the interaction quality of Boring Notch:

- top-centered overlay panel
- notch-matched closed state
- hover-based expansion
- premium, dark visual language
- subtle haptic confirmations

### Technical path

- `NSPanel` for the overlay window
- `NSScreen` safe-area and auxiliary top-area geometry for notch matching
- SwiftUI for rendering
- AppKit-driven window behavior and z-order
- `NSHapticFeedbackManager` for tactile feedback where supported

### Feasibility

High.

This is a normal macOS overlay-window problem. The difficult part is polish, not access.

### Risk

Low technically.
Medium product-wise if the app copies too literally instead of defining its own information design.

### Recommended V1

- target motion and tactile parity
- preserve your own module hierarchy
- make haptics configurable

### Research notes

- Apple exposes AppKit haptic feedback primitives through `NSHapticFeedbackManager`.
- `NSPanel` and top-screen overlay behavior are well-supported.

Sources:

- https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager
- https://developer.apple.com/documentation/appkit/nspanel

## 2. Apple Calendar Integration

### Best path

Use EventKit.

### Why

EventKit is the standard Apple framework for reading calendar events and reminders on macOS. It is the cleanest and most stable path for showing:

- current event
- next event
- event countdown
- calendar filtering

### Data available

- calendars
- events
- reminders
- start and end times
- titles
- notes and metadata

### Permissions

- macOS calendar permission via EventKit

### Sync model

- initial load on permission grant
- event store change observation
- local cache for fast closed-state rendering

### Feasibility

High.

### Risk

Low.

### Recommended V1

- read-only calendar integration
- selected calendars only
- “current / next” summary in the closed notch
- richer event list in the open panel

Sources:

- https://developer.apple.com/documentation/eventkit
- https://developer.apple.com/documentation/eventkit/accessing_calendar_using_eventkit_and_eventkitui

## 3. Codex Integration

### Best path

Use a local observer adapter first.

### Why

On this machine, Codex has a substantial local footprint in `~/.codex`, including:

- `sessions/`
- `history.jsonl`
- `session_index.jsonl`
- `state_5.sqlite`
- `config.toml`

That means `Notch-` can likely infer:

- recent session activity
- latest work timestamp
- active workspaces
- session creation cadence

without needing a formal public runtime API.

### What I observed locally

- session files are stored in dated directories under `~/.codex/sessions/YYYY/MM/DD/`
- Codex also persists global indexes and a state SQLite database

### Official integration status

I did not find a clear official OpenAI-documented local “running session status API” that `Notch-` can depend on directly.

That means the integration should be treated as:

- local observation first
- optional wrapper / launcher later

### V1 strategy

Use:

- filesystem watching
- timestamp parsing
- session index parsing
- optional “currently active workspace” heuristics

Optional later:

- a Codex launcher wrapper that emits structured status events to `Notch-`

### Feasibility

Medium.

### Risk

Medium, because local file structures can change.

### Recommended V1

- show recent activity / active today / latest session workspace
- avoid pretending to know exact token-level or tool-level status unless there is a verified source

## 4. Claude Code Integration

### Best path

Use a dual path:

1. local observer
2. optional hooks adapter

### Why

On this machine, Claude Code persists data under `~/.claude`, including:

- `projects/`
- `history.jsonl`
- `debug/`
- `todos/`
- `telemetry/`

Anthropic also documents Claude Code hooks, which can run custom logic at lifecycle points.

That makes Claude Code the strongest agent-monitoring target after OpenClaw.

### Data available

From local state:

- recent sessions
- workspace identities
- timestamps
- todo-related artifacts

From hooks:

- structured lifecycle events
- tool-use boundaries
- session transitions

### Permissions / setup

- local file access for `~/.claude`
- optional user-configured Claude Code hooks emitting events to `Notch-`

### Feasibility

High.

### Risk

Medium if relying only on internal file formats.
Lower if hooks are used.

### Recommended V1

- ship local-observer adapter first
- add optional hook-based enhancement mode

### Research notes

Claude Code hooks are the cleanest way to get explicit state transitions without reverse-engineering everything from files.

Sources:

- https://docs.anthropic.com/en/docs/claude-code/hooks

## 5. OpenClaw Integration

### Best path

Use a first-class gateway adapter.

### Why

OpenClaw appears to expose a clearer control-plane model than Codex or Claude Code. Its public README describes:

- a local Gateway
- a WebSocket control plane
- session tooling
- agent sessions and workspace concepts

It also documents a default local gateway endpoint:

- `ws://127.0.0.1:18789`

### Data available

Potentially:

- session list
- session history
- session send / coordination primitives
- agent / gateway health

### Permissions / setup

- local network loopback access
- user-configured connection details if the gateway runs remotely

### Feasibility

High, if the user actually runs OpenClaw and the gateway is available.

### Risk

Medium, because the gateway may not always be local and because I have not verified a running OpenClaw instance on this machine.

### Recommended V1

- build a configurable OpenClaw adapter
- assume one or more known gateway endpoints
- show connected / disconnected / active session counts

### Research notes

OpenClaw is the most promising of the three agent systems for explicit structured monitoring.

Sources:

- https://github.com/openclaw/openclaw
- https://docs.openclaw.ai/concepts/session-tool
- https://docs.openclaw.ai/gateway

## 6. Running Local Hosts

### Best path

Use a configured service registry plus active health probes.

### Why

There are several ways to detect local hosts:

- process inspection
- socket inspection
- configured list of expected local services
- wrapper-launched dev servers that report into `Notch-`

For a stable V1, the best path is not deep process inspection. The best path is:

- let the user define local services
- store name, port, URL, and optional health endpoint
- probe on an interval

### Data available

With a configured service registry:

- online / offline
- response time
- HTTP status
- route health

With optional future enhancements:

- owning process
- project path
- dev server type

### Permissions / setup

- no special OS permissions needed for local HTTP probes
- optional local file or wrapper integration for richer metadata

### Feasibility

High.

### Risk

Medium if automatic detection is attempted too early.

### Recommended V1

- user-managed service list
- ping / health endpoint probing
- open in browser action
- “down” and “recovered” peek notifications

### Optional future path

- project manifests
- wrapper commands like `notch dev start`
- process-to-port mapping if you later choose a privileged mode

## 7. Habits with Notion Integration

### Best path

Use a local-first habit model with Notion sync.

### Why

Notion’s API is strong enough for:

- searching content
- reading pages
- reading and querying data sources
- syncing structured habit entries

The product should not depend on live Notion round-trips for the closed state. It should maintain a local cache and sync in the background.

### Data model recommendation

Represent habits as either:

- one data source for habit definitions
- one data source for daily habit entries

or:

- one daily journal page with structured habit properties

### Auth

- Notion internal integration token for personal use
- optional OAuth later if the product expands to multiple users

### Feasibility

High.

### Risk

Low.

### Recommended V1

- local-first habits
- background Notion sync
- write-back for completion toggles if the user opts in

### Research notes

Notion’s newer API language emphasizes data sources in addition to legacy database concepts. `Notch-` should design its connector around queryable structured collections, not hardcoded legacy assumptions.

Sources:

- https://developers.notion.com/reference/intro
- https://developers.notion.com/reference/authentication
- https://developers.notion.com/reference/post-search
- https://developers.notion.com/reference/data-source-query
- https://developers.notion.com/reference/webhooks

## 8. Current Learnings

### Best path

Treat current learnings as a first-party object with optional Notion sync.

### Why

There is no universal “learning API.” If this module is vague, it will become noisy.

The cleanest model is:

- one current learning focus
- optional list of active learning entries
- quick capture
- optional sync to a Notion learning log

### Suggested structure

- `topic`
- `why it matters`
- `current source`
- `next action`
- `notes`
- `last reviewed`

### Feasibility

High.

### Risk

Low technically.
Medium conceptually if the model is not defined tightly.

### Recommended V1

- local-first learning entries
- one highlighted “current learning focus”
- optional Notion sync

### Optional later paths

- ingest markdown notes from selected directories
- connect to read-later systems
- weekly learning review

## 9. Pomodoro / Time Tracking

### Best path

Build it as a first-party local engine.

### Why

Pomodoro is core product behavior, not an external integration problem.

The notch is especially strong for:

- live countdown visibility
- completion peeks
- subtle haptic finish
- easy start / pause / resume

### Data available

- current session state
- elapsed time
- completed sessions
- optional task association

### Optional integrations later

- write focus blocks to Notion
- create calendar blocks
- local reports and review summaries

### Feasibility

High.

### Risk

Low.

### Recommended V1

- first-party timer
- session history
- configurable work / break lengths
- haptic and peek completion states

## 10. Recommended Adapter Order

### Phase 1

- Apple Calendar
- Notion habits
- Pomodoro
- localhost monitoring

### Phase 2

- Claude Code local observer
- Codex local observer

### Phase 3

- OpenClaw gateway adapter
- Claude hooks adapter
- Codex wrapper emitter

## 11. Recommended V1 Architecture Choice

For V1, `Notch-` should use:

- one public-API-safe UI shell
- one local event bus
- local persistence
- adapter connectors per source

The strongest product posture is:

- polished shell first
- reliable schedule / habits / focus second
- agent monitoring third

because that already gives the notch daily value even before every agent adapter becomes perfect.

## 12. Source Notes

### Local observations on this machine

Observed local footprints:

- Codex:
  - `~/.codex/sessions/`
  - `~/.codex/history.jsonl`
  - `~/.codex/session_index.jsonl`
  - `~/.codex/state_5.sqlite`
- Claude Code:
  - `~/.claude/projects/`
  - `~/.claude/history.jsonl`
  - `~/.claude/debug/`
  - `~/.claude/todos/`
- OpenClaw:
  - no `~/.openclaw` directory was found on this machine at the time of research

That means the OpenClaw integration should be treated as a configurable external adapter unless and until a local installation is present.
