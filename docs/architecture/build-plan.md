# Notch- Build Plan

Date: March 11, 2026
Status: Active

## Purpose

This document defines the execution sequence for implementing the page-driven PRD while preserving the shell-first architecture.

> [!TIP]
> The current repository status against this plan is tracked in [current-state](./current-state.md). Page-level implementation needs are defined in the [PRD](../prd/ultimate-notch-app-prd.md).

## Build Strategy

`Notch-` should be built in five stages:

1. shell foundation
2. core app spine
3. daily operations pages
4. communication and agent pages
5. advanced utility and financial pages

This preserves the original shell-first and low-risk sequence while enabling the expanded page set.

Current execution note (March 26, 2026):

- Phase 2 calendar/localhost/habits surfaces are active, and the Time Tracking page is now fully interactive.
- Phase 3 Media Control is beyond UI baseline and now reads live Spotify/Apple Music runtime state through local automation.
- Phase 3 Agents Status now has an active shell page and baseline local observer adapter wiring for Codex/Claude session snapshots.
- Phase 4 has started early for HUD parity: camera preview + full-display stream preview are active in the HUD page.

## Validation Rule

After any code-editing task, run dedicated tests for the subsystem that changed.

Validation must be page-aware:

- shell edits: geometry, state transitions, display behavior, haptics, symbol bar
- infrastructure edits: event bus, persistence, adapter lifecycle, permissions, diagnostics
- page edits: page-specific adapter tests, domain model tests, and page UI tests

Manual hardware checks complement automated testing but do not replace it.

## Page Sequencing Matrix

| Page | Primary phase | Why this phase |
| --- | --- | --- |
| Home | 3 | Depends on summaries from other foundational modules |
| Notifications | 4 | Requires cross-app ingestion and normalization pipeline |
| Calendar | 3 | High value, stable EventKit integration |
| Media Control | 4 | Provider auth and transport abstraction complexity |
| Habits | 3 | Local-first value plus Notion sync |
| Agents Status | 4 | Depends on heterogeneous provider observability |
| HUD | 5 | Hardware/permission-heavy and latency-sensitive |
| Localhost | 3 | Stable probe model, immediate developer value |
| OpenClaw | 4 | Gateway/chat transport and metrics model |
| Financial Board | 5 | Connector and reconciliation complexity |

## Phase 0: Shell Foundation

> [!TIP]
> Implementation research for this phase lives in [Phase 0 shell research](../research/phase-0-shell-research.md).

Build the notch shell before external integrations.

### Scope

- Xcode macOS app scaffold with unit/UI test targets
- `NSPanel` overlay shell and notch geometry resolution
- closed / peek / open shell states
- hover behavior and shell animation rhythm
- shell haptics service
- top symbol bar frame and page routing scaffold
- settings launch from shell header

### Exit Criteria

- shell is runnable and stable on target hardware
- settings can launch from the symbol bar
- shell behavior tests pass (geometry, state, coordinator, windowing)
- UI smoke test for shell root and settings launch path passes where environment permits

## Phase 1: Core App Spine

Build the shared infrastructure all pages require.

### Scope

- local persistence layer
- event bus
- adapter registry
- module/page registry
- permissions manager
- diagnostics and adapter health surface
- typed settings store and propagation into shell behavior
- closed-state prioritization service

### Exit Criteria

- pages can register independently with normalized contracts
- adapters can start/stop/restart without shell instability
- settings update live behavior without relaunch where practical
- infrastructure tests pass for store, event bus, registry, and coordinator boundaries

## Phase 2: Daily Operations Pages

Build the highest-confidence, daily-value pages first.

### Pages in scope

- Calendar
- Localhost
- Focus (Pomodoro)
- Habits + Learnings local models
- Home (summary cards based on available page data)

### Core implementation points

- EventKit-backed calendar read path and quick-create foundations
- localhost service registry and health probes
- Pomodoro timer engine and completion events
- local-first habits/learnings storage and metrics
- home summary aggregation service with freshness and priority ranking

### Exit Criteria

- closed state can summarize next event, focus, localhost health, habits progress
- open pages above are useful with real data, not placeholders
- page-specific tests pass for Calendar, Localhost, Focus, Habits/Learnings, Home aggregation

Current status note:

- Calendar page reads real EventKit events/reminders.
- Time Tracking is active in UI/runtime with local timer/session behavior.

## Phase 3: Communication And Agent Pages

Build pages with higher integration variability once the shell and spine are proven.

### Pages in scope

- Notifications
- Media Control
- Agents Status
- OpenClaw

### Core implementation points

- notification ingestion and source normalization for WhatsApp/Discord/Instagram/Telegram
- media provider abstraction for Spotify and Apple Music
- agent adapters for Codex, Claude Code, Ollama, OpenCode with `ongoing`/`idle` mapping
- OpenClaw chat transport plus runtime metrics channel

### Exit Criteria

- notifications render with source grouping and recency ordering
- media controls and queue/recent views function with at least one authenticated provider
- agents page shows status + process summary; usage fields degrade cleanly when unavailable
- OpenClaw split panel works with connection and degraded modes
- adapter and page tests pass for all added integrations

Current status note:

- Media controls and now-playing state are already active for local Spotify/Apple Music app sessions.
- Agents Status is now active with local observer snapshots flowing through `AdapterRegistry` and the runtime event bus.
- Remaining work is provider hardening, richer queue semantics, deeper agent event signals, and broader regression coverage.

## Phase 4: Advanced Utility And Financial Pages

Build hardware-sensitive and business-data-heavy pages after core workflow value is established.

### Pages in scope

- HUD
- Financial Board

### Core implementation points

- camera/HUD surfaces with stream-display utility controls
- financial connector abstraction, KPI normalization, chart aggregation

### Exit Criteria

- HUD is stable across permission states and hardware contexts
- financial page shows per-business profit, MRR, revenue, and trend charts
- reliability and degraded-mode tests pass for permission denial and connector failure paths

Current status note:

- HUD camera and stream-preview surfaces are now implemented and running in open-shell page layout.
- Remaining HUD work is resilience/performance hardening and optional detached utility-window behavior.

## Phase-Level Validation Matrix

- Phase 0: shell behavior tests + UI smoke checks
- Phase 1: infrastructure contract and lifecycle tests
- Phase 2: calendar/localhost/focus/habits/home page tests
- Phase 3: notifications/media/agents/openclaw adapter + page tests
- Phase 4: HUD permission/performance tests + financial KPI/connector tests

## Best First Milestone

The first milestone should prove daily usefulness before broad integration breadth:

- stable notch shell
- one closed-state summary row
- open-state routing surface
- Calendar next event
- Pomodoro timer
- 2 to 3 localhost services

Then layer habits and home summaries before communication and agent pages.

## What Not To Do First

- do not start with all page integrations in parallel
- do not build financial and HUD before the core workflow pages are stable
- do not require provider auth for baseline shell usefulness
- do not let uncertain agent metrics block page delivery

## Dependencies

This plan depends on:

- [Ultimate Notch app PRD](../prd/ultimate-notch-app-prd.md)
- [Integration research](../research/integration-research.md)
- [Integration matrix](../research/integration-matrix.md)
- [Adapter architecture](./adapter-architecture.md)

## Decision

The recommended implementation order is:

1. shell
2. core infrastructure
3. Calendar + Localhost + Focus + Habits/Learnings + Home summaries
4. Notifications + Media + Agents + OpenClaw
5. HUD + Financial
