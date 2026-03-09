# Notch- Integration Matrix

Date: March 9, 2026
Status: Draft

> [!TIP]
> Use this matrix together with the [build plan](../architecture/build-plan.md) to decide sequence, not just feasibility.

## Purpose

This matrix turns the broader research into an implementation-oriented view.

Each row defines:

- source of truth
- access method
- permission or auth requirement
- freshness model
- normalized entities
- fallback behavior
- V1 build order

## Matrix

| Integration | Source of truth | Access method | Auth / permission | Freshness model | Normalized entities | Failure mode | V1 recommendation | Phase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Boring Notch-grade shell | macOS display + app state | AppKit + SwiftUI + `NSScreen` + `NSPanel` | none beyond normal app runtime | event-driven UI state | `Signal`, `ModuleCard`, `Action` | falls back to plain overlay behavior | required foundation | 0 |
| Haptics | local hardware capability | `NSHapticFeedbackManager` | none | event-driven | `HapticEvent` | silent fallback if unsupported | required foundation | 0 |
| Apple Calendar | Calendar database | EventKit | calendar permission | event store change + periodic refresh | `CalendarItem`, `Event` | module unavailable / empty state | ship | 1 |
| Notion habits | Notion data source | HTTPS API | integration token or OAuth | periodic sync + optional webhook | `HabitEntry` | local-only mode | ship | 1 |
| Notion learnings | Notion data source | HTTPS API | integration token or OAuth | periodic sync + optional webhook | `LearningEntry` | local-only mode | ship | 1 |
| Pomodoro | local app store | first-party engine | none | second-level timer tick | `FocusSession`, `Event` | local timer reset / persistence restore | ship | 1 |
| Localhost services | configured local endpoints | HTTP health probes | none | polling | `LocalService`, `Event` | service marked down / unknown | ship | 1 |
| Claude Code basic | `~/.claude` state | local filesystem observer | file access | filesystem watch + debounce | `AgentSession`, `AgentEvent` | stale state / degraded confidence | ship | 2 |
| Codex basic | `~/.codex` state | local filesystem observer | file access | filesystem watch + debounce | `AgentSession`, `AgentEvent` | stale state / degraded confidence | ship | 2 |
| OpenClaw gateway | local or remote gateway | WebSocket / gateway API | local gateway access, token if needed | push or frequent pull | `AgentSession`, `AgentEvent`, `Signal` | disconnected gateway state | ship if available | 2 |
| Claude Code enhanced | Claude hooks | command hook emitter | user hook config | event-driven push | `AgentEvent` | falls back to filesystem observer | add after basic | 3 |
| Codex enhanced | wrapper / launcher emitter | local helper or wrapper | user uses wrapped launch path | event-driven push | `AgentEvent` | falls back to filesystem observer | add after basic | 3 |
| OpenClaw advanced | session history and controls | gateway session tools | local or remote auth | push + on-demand fetch | `AgentSession`, `Action` | read-only degraded mode | add after core gateway | 3 |
| Localhost advanced | process-aware host mapping | process + socket inspection | may require broader machine access | event-driven + poll | `LocalService`, `WorkspaceContext` | unknown owner / degraded mapping | postpone | 4 |

## Normalized Models

### `AgentSession`

Minimum shape:

- `id`
- `provider`
- `workspacePath`
- `title`
- `status`
- `lastActivityAt`
- `confidence`

### `AgentEvent`

Minimum shape:

- `id`
- `provider`
- `sessionId`
- `kind`
- `message`
- `timestamp`
- `severity`

### `LocalService`

Minimum shape:

- `id`
- `name`
- `url`
- `healthcheckUrl`
- `status`
- `responseTimeMs`
- `lastCheckedAt`

### `HabitEntry`

Minimum shape:

- `id`
- `title`
- `date`
- `completed`
- `streak`
- `source`

### `LearningEntry`

Minimum shape:

- `id`
- `topic`
- `status`
- `nextAction`
- `source`
- `updatedAt`

### `FocusSession`

Minimum shape:

- `id`
- `mode`
- `startedAt`
- `endsAt`
- `status`
- `associatedTask`

## Confidence Rules

The agent integrations should expose confidence explicitly.

Suggested levels:

- `high`
  - direct structured event source or documented API
- `medium`
  - stable local file observation with predictable semantics
- `low`
  - inferred status from timestamps or weak heuristics

Recommended by connector:

- OpenClaw gateway: `high`
- Claude hooks: `high`
- Claude local observer: `medium`
- Codex local observer: `medium` to `low`, depending on signal quality
- localhost configured health probes: `high`

## Build Order

### Phase 0: foundation

- overlay shell
- haptics service
- event bus
- local store
- module registry

### Phase 1: guaranteed-value modules

- calendar
- habits
- learnings
- Pomodoro
- localhost probes

### Phase 2: agent visibility

- Claude local observer
- Codex local observer
- OpenClaw gateway adapter

### Phase 3: enhanced integrations

- Claude hook bridge
- Codex launcher wrapper
- OpenClaw drill-down and controls

### Phase 4: deeper machine awareness

- localhost process ownership
- richer project-to-service mapping

## Recommended Shipping Rule

No integration should be allowed to block the shell.

If a connector fails:

- the shell still renders
- the module shows a degraded state
- the closed notch falls back to other healthy signals

## Decision

The best first implementation path is:

1. ship the shell and local-first personal modules
2. add observer-based agent monitoring
3. add explicit event-driven agent integrations where the external system supports them

For the concrete sequence, see the [build plan](../architecture/build-plan.md).
