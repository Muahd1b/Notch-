# Notch- Current Implementation State

Date: March 11, 2026
Status: Active

## Purpose

This document tracks what is implemented in the repository today and what that means for the next build step.

Use this together with the [build plan](./build-plan.md). The build plan defines the target sequence. This document defines current reality.

## Current Phase

The repository now spans:

- late Phase 0 for shell behavior and interaction polish
- early Phase 1 for core runtime spine scaffolding
- late Phase 2 for daily-operations page surfaces
- active Phase 3 for communication/media integrations
- early Phase 4 utility work for HUD behavior

Implemented today:

- runnable macOS app target with unit and UI test targets
- AppKit-owned shell lifecycle and display coordination
- real notch geometry resolution using `NSScreen`-derived data
- two-state shell model: `closed` and `open(reason)`
- controller-owned hover entry, hover sustain, and hover-exit closing
- non-activating `NSPanel` overlay shell with stable open-window footprint
- notch-matched shape primitives, shell sizing constants, and Boring-style open-shell metrics
- fixed-size open shell viewport with internal scrolling instead of content-driven outer resizing
- stable shell shadow/fade attached to the shell container rather than to per-page content
- expanded open-shell top bar with 10 page symbols split across left and right notch sides
- typed local settings registry with persisted shell and module-facing keys
- settings window shell with adapted `Notch-` sidebar and grouped forms
- shell-focused unit tests plus one UI smoke test for settings launch
- initial core spine services:
  - event bus
  - persistence store
  - adapter registry and contract
  - permissions manager
  - diagnostics service
  - page registry
  - runtime services container wired into app startup
- dedicated unit tests for the above core spine services
- open-state page rendering with real tab-specific bodies for:
  - Home overview
  - Calendar split layout (left quick-create, right timeline list)
  - Time Tracking split layout (left timer controls, right session log/metrics)
  - Media Control split layout (left Boring-style transport panel, right queue/recent list)
  - Localhost split layout (service list + runtime metrics)
  - Habits/Learnings split layout (habit list + progress/learnings metrics)
  - HUD split layout (left camera mirror card, right display-stream preview card)
- tab/page interaction haptics mapped through `NSHapticFeedbackManager`
- UI coverage for Calendar, Localhost, and Habits tab routing in shell open state
- Calendar interaction parity improvements:
  - center-aligned day carousel selection with haptic ticks
  - broader EventKit fetch window and stale-calendar fallback behavior
  - nested timeline scrolling fixed by disabling outer vertical scroll on Calendar/Media/HUD pages
- media integration now runs against real local app state:
  - Spotify and Apple Music playback state polling + distributed-notification refresh
  - transport control, shuffle/repeat, volume, and recent-track merging
  - automation-permission diagnostics surfaced in status text
- HUD services now use AVFoundation capture sessions:
  - camera preview with mac camera preference and permission-aware fallback
  - full-display stream preview with screen-recording permission flow

Not implemented yet:

- production adapters/pages for notifications, agents status, OpenClaw, and financial board
- persisted focus session history and cross-page focus analytics aggregation
- detached utility windows for HUD stream workflows (current HUD stream is in-notch preview)
- full `peek` behavior and deeper page-specific domain rendering for remaining placeholder pages

## Repository Structure

The codebase is now organized around the working shell runtime instead of one flat `Shell/` bucket.

### App bootstrap

- `Notch-/App/NotchApp.swift`
- `Notch-/App/ShellAppDelegate.swift`

### Shell core

- `Notch-/Shell/Core/ShellPresentationState.swift`
- `Notch-/Shell/Core/ShellViewModel.swift`
- `Notch-/Shell/Core/ShellGeometryResolver.swift`
- `Notch-/Shell/Core/ShellDisplay.swift`
- `Notch-/Shell/Core/ShellSizing.swift`
- `Notch-/Shell/Core/ShellStatusSnapshot.swift`
- `Notch-/Shell/Core/HapticsService.swift`

### Shell windowing

- `Notch-/Shell/Windowing/ShellCoordinator.swift`
- `Notch-/Shell/Windowing/ShellPanel.swift`
- `Notch-/Shell/Windowing/ShellWindowController.swift`

### Shell UI

- `Notch-/Shell/UI/NotchShape.swift`
- `Notch-/Shell/UI/ShellHeaderView.swift`
- `Notch-/Shell/UI/ShellRootView.swift`
- `Notch-/Shell/UI/Open/ShellOpenContentView.swift`
- `Notch-/Shell/UI/Open/ShellCalendarColumnView.swift`
- `Notch-/Shell/UI/Open/ShellActivityListView.swift`

### Settings

- `Notch-/Settings/Store/AppSettings.swift`
- `Notch-/Settings/Windowing/SettingsWindowController.swift`
- `Notch-/Settings/UI/SettingsView.swift`

### Core runtime spine

- `Notch-/Core/EventBus/NotchEventBus.swift`
- `Notch-/Core/Persistence/PersistenceStore.swift`
- `Notch-/Core/Adapters/AdapterRegistry.swift`
- `Notch-/Core/Permissions/PermissionsManager.swift`
- `Notch-/Core/Diagnostics/RuntimeDiagnostics.swift`
- `Notch-/Core/Pages/PageRegistry.swift`
- `Notch-/Core/Runtime/CoreRuntimeServices.swift`

### Test coverage currently present

- `Notch-Tests/Shell/Core/ShellGeometryResolverTests.swift`
- `Notch-Tests/Shell/Core/ShellViewModelTests.swift`
- `Notch-Tests/Shell/Windowing/ShellCoordinatorTests.swift`
- `Notch-Tests/Shell/Windowing/ShellPanelTests.swift`
- `Notch-Tests/Shell/Windowing/ShellWindowControllerTests.swift`
- `Notch-Tests/Core/NotchEventBusTests.swift`
- `Notch-Tests/Core/PersistenceStoreTests.swift`
- `Notch-Tests/Core/AdapterRegistryTests.swift`
- `Notch-Tests/Core/PermissionsManagerTests.swift`
- `Notch-Tests/Core/RuntimeDiagnosticsTests.swift`
- `Notch-Tests/Core/PageRegistryTests.swift`
- `Notch-Tests/Core/CoreRuntimeServicesTests.swift`
- `Notch-UITests/Shell/ShellUITests.swift`

## Runtime Ownership

The active shell runtime path is:

1. `NotchApp` boots through `ShellAppDelegate`.
2. `ShellAppDelegate` starts `CoreRuntimeServices` (event bus, persistence, registry, permissions, diagnostics, page registry).
3. `ShellCoordinator` selects the preferred display and owns window lifecycle.
4. `ShellWindowController` owns frame updates, hover-open timing, hover-close behavior, and tracking-rect sync.
5. `ShellPanel` owns AppKit tracking-area updates.
6. `ShellRootView` owns shell chrome, shadow composition, and closed/open shell framing.
7. `ShellOpenContentView` owns the fixed open viewport and delegates tab content to open-state UI views.

Important note:

- shell hover-open is no longer driven by `ShellViewModel` alone
- the authoritative hover path now lives in the window controller and panel
- the view model only owns shell state, selected tab state, snapshot state, and pointer-hover flag

## Reality Check Against The Build Plan

Completed or mostly completed Phase 0 items:

- app scaffold
- unit and UI test targets
- `NSPanel` overlay shell
- notch geometry resolver
- shell shape, sizing, header, and settings-shell primitives
- controller-owned hover behavior and close-on-exit behavior
- initial haptics service
- dedicated shell unit tests

Phase 1 groundwork completed:

- core event bus scaffold
- persistence store scaffold
- adapter lifecycle registry scaffold
- permissions state manager scaffold
- diagnostics buffer and publishing scaffold
- page registry scaffold
- dedicated core infrastructure tests

Phase 0 gaps still open:

- no hardware-validated gesture system beyond current shell interactions
- UI coverage is still thin compared with the amount of shell behavior now living in AppKit
- page routing is real, but notifications/agents/openclaw/financial pages still use placeholder bodies
- the build plan still describes `peek` as part of the wider target model, but the current implementation is intentionally focused on stable `closed` / `open` shell parity first

Phase 1 gaps still open:

- adapter registration/lifecycle is scaffolded, but page services are still mostly invoked directly from `CoreRuntimeServices` instead of fully adapter-driven wiring
- no production adapter implementations are registered in `AdapterRegistry` for notifications/media/agents/openclaw/financial domains
- event bus domain modeling is still uneven across modules (calendar/media are active; remaining pages still pending)

Phase 2 progress:

- visual/interaction parity pass implemented for Calendar, Localhost, Habits/Learnings, and Time Tracking page layouts
- page-level selection and quick-action haptics are now wired
- Calendar now reads live EventKit events/reminders with source filters and permission-aware fallback behavior
- remaining Phase 2 work is deeper adapter/event actions and persistence hardening (direct quick-create UX, localhost configuration UX, richer focus history persistence)

Phase 3 progress:

- Media Control page now has a concrete split UI implementation in shell open state:
  - left side transport/now-playing panel modeled after Boring Notch media panel composition
  - right side queue/recent list rendered with the same event-row typography system used by Calendar
- media state is now sourced from live Spotify/Apple Music app state via AppleScript + distributed notifications
- remaining Phase 3 media work is provider-hardening (deeper queue APIs, richer error mapping, and automated test coverage across provider states)

Phase 4 progress:

- HUD page is now active with camera and full-screen stream cards in open shell state
- HUD camera service handles permission state, settings handoff, and live preview rendering
- HUD stream service handles screen-recording permission flow and main-display capture preview
- HUD layout was compacted to avoid page scrolling and preserve fixed open-shell alignment

## Page Progress Snapshot

### Calendar

- Live EventKit read path is wired (`events` + `reminders`) with source filtering from settings.
- Left quick-create actions are wired to launch Apple Calendar / Reminders for fast capture.
- Event timeline now scrolls independently while the shell page remains fixed.

### Time Tracking

- Time Tracking page is fully interactive (start focus, start break, pause/resume, stop).
- Local timer phase transitions and end-of-session notifications are active.
- Session notes and recent session log are live in-memory for the current runtime session.

### Media

- Media page is connected to Spotify and Apple Music runtime state when automation permissions allow.
- Transport controls, shuffle/repeat, volume, artwork refresh, and recent-track lists are active.
- Status messaging now degrades explicitly for disabled integrations, missing apps, and Automation denial.

### HUD

- HUD page now includes live camera mirror and live full-screen preview cards.
- Camera selection prioritizes Mac camera devices before Continuity Camera fallback.
- Screen stream uses main-display capture and permission-aware settings redirection.

## Recommended Next Build Step

Keep hardening the now-live Calendar, Time Tracking, Media, and HUD pages while completing the remaining placeholder domains.

Recommended order:

1. Harden page reliability and degraded modes for Calendar/EventKit, Media automation, HUD permissions, and Time Tracking timer transitions.
2. Expand UI and integration test coverage for the four active pages to reduce regressions from shell-level changes.
3. Finish next placeholder pages in priority order: Notifications, Agents Status, OpenClaw, then Financial Board.
4. Move page services toward adapter-registered runtime ownership so data flow is consistently adapter -> event bus -> store -> UI.

## Documentation Usage

- For product boundaries: [PRD](../prd/ultimate-notch-app-prd.md)
- For sequencing: [build plan](./build-plan.md)
- For repository layout: [repository structure](./repository-structure.md)
- For open-shell page routing and symbols: [symbol bar page map](./symbol-bar-page-map.md)
- For shell implementation details: [Phase 0 shell research](../research/phase-0-shell-research.md)
- For settings-system direction: [Boring Notch settings research](../research/boring-notch-settings-research.md)
- For exact upstream implementation files: [Boring Notch source map](../reference/boring-notch-source-map.md)
- For page-level settings contents to port later: [Boring Notch settings catalog](../reference/boring-notch-settings-catalog.md)
- For future integration work: [integration research](../research/integration-research.md) and [integration matrix](../research/integration-matrix.md)
