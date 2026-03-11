# Notch- Repository Structure

Date: March 11, 2026
Status: Active

## Purpose

This document explains the current repository layout after shell foundation and initial Phase 1 spine scaffolding.

It is intentionally based on what exists today, not on aspirational module extraction that has not been implemented yet.

## Current Layout

### `Notch-/App`

Application bootstrap and runtime composition entrypoint.

- `NotchApp.swift`
- `ShellAppDelegate.swift`

### `Notch-/Core`

Shared runtime spine services introduced in early Phase 1:

- `EventBus/`: event fan-out and buffered subscriptions
- `Persistence/`: local structured persistence primitives
- `Adapters/`: adapter contracts and lifecycle registry
- `Permissions/`: permission state tracking and publication
- `Diagnostics/`: runtime diagnostics buffering and event emission
- `Pages/`: page registration and ordering
- `Runtime/`: composition container for core services

### `Notch-/Shell/Core`

Pure shell state, geometry, sizing, display, and shell snapshot data.

- shell state and open reasons
- view model
- notch geometry resolver
- display selection helpers
- haptics service
- shell status snapshot used by current page UI

### `Notch-/Shell/Windowing`

AppKit ownership for the notch overlay.

- panel configuration
- shell coordination
- hover tracking
- window frame updates
- display refresh behavior

### `Notch-/Shell/UI`

SwiftUI rendering for the shell itself.

- notch shape
- shell header
- root shell composition and shadow container
- `Open/` subdirectory for fixed open-state viewport and tab content
- current implemented open-state pages include:
  - Home
  - Calendar
  - Time Tracking
  - Media Control
  - Localhost
  - Habits/Learnings
  - HUD

### `Notch-/Settings`

Settings are split by responsibility, not by future product domain.

- `Store/`: persisted settings state
- `Windowing/`: settings window controller
- `UI/`: settings forms and sidebar

### `Notch-Tests/Shell`

Shell tests are grouped the same way as the app code:

- `Core/`
- `Windowing/`

### `Notch-Tests/Core`

Phase 1 infrastructure tests:

- event bus delivery and buffering
- adapter registry lifecycle
- persistence encoding/decoding behavior
- permission state publication
- runtime diagnostics buffering/events
- page registration and ordering
- runtime service startup wiring

### `Notch-UITests/Shell`

UI smoke coverage for shell/settings plus open-state page routing for key tabs.

## Structural Rules

- Keep shell runtime ownership in `Shell/Windowing`, not in SwiftUI view code.
- Keep rendering concerns in `Shell/UI`.
- Keep state and pure calculation logic in `Shell/Core`.
- Keep open-state scrollable content in `Shell/UI/Open` so `ShellRootView` remains shell chrome, not page content.
- Keep cross-page services in `Notch-/Core` and avoid leaking adapter/store logic into `Shell/` or `Settings/`.
- When new runtime surfaces are added, place them by current responsibility, not by aspirational architecture.

## Expected Future Change

This layout is intentionally conservative.

After the core spine is stable, the repository will likely grow additional areas for:

- real data modules
- adapters and sync

That change should happen only when those systems exist in code, not before.
