# Notch- Codebase Gap Analysis

Date: March 26, 2026  
Status: Active audit snapshot

## Purpose

This document captures the current implementation gaps in the full repository and maps them to the intended architecture and build sequence.

Use this with:

- `docs/architecture/current-state.md`
- `docs/architecture/build-plan.md`
- `docs/architecture/adapter-architecture.md`

## Scope Reviewed

- App bootstrap, shell runtime, shell UI, settings UI/store, core runtime services, adapters/event bus/persistence/permissions/diagnostics/page registry, unit tests, and UI tests.

Primary code references:

- `Notch-/App/*`
- `Notch-/Shell/*`
- `Notch-/Core/*`
- `Notch-/Settings/*`
- `Notch-Tests/*`
- `Notch-UITests/*`

## Implemented vs Missing

### Implemented and functional

- Shell lifecycle and multi-display panel coordination.
- Open-state pages with real behavior:
  - Calendar (`EventKit` read + quick-create launch/actions)
  - Localhost (probe + runtime metrics sampling)
  - Habits/Learnings local model
  - Focus timer runtime
  - Media runtime (Spotify/Apple Music AppleScript-driven control + polling)
  - HUD runtime (camera preview + screen capture preview)

### Still placeholder pages

- Notifications
- Agents Status
- OpenClaw
- Financial Board

These are still rendered by `ShellFeaturePlaceholderPageView` in `Notch-/Shell/UI/Open/ShellOpenContentView.swift`.

## Architecture Gaps (Highest Impact)

### 1. Adapter architecture is scaffolded but not driving runtime

- `AdapterRegistry` exists and supports lifecycle/health events.
- No production adapters are registered by `CoreRuntimeServices`.
- Most integrations are called directly as private service actors from `CoreRuntimeServices`, bypassing adapter registration contracts.

Impact:

- Domain connectors are not uniformly isolated behind adapter boundaries.
- Health/confidence reporting is not a reliable source of truth for active integrations.

### 2. Event bus is mostly write-only

- Many components publish to `NotchEventBus`.
- No production consumer subscribes to bus streams for domain state composition.

Impact:

- Runtime behavior is not actually event-driven yet.
- Event bus works as telemetry buffering rather than module coordination.

### 3. Page registry is not used for runtime routing

- `PageRegistry` exists and is tested.
- Shell tab/header routing currently uses static `ShellOpenTab` enum and view-level switching.
- No runtime binding from `PageRegistry` into active shell tab visibility/order.

Impact:

- Page enable/disable/order controls are not centrally enforced.

### 4. Focus data is not persisted

- Focus sessions are in-memory (`ShellViewModel.focusSessionRecords`).
- No persistence write/read path for focus session history.

Impact:

- Focus history resets on app restart.
- Cross-page analytics/longitudinal insights are blocked.

### 5. Localhost configuration is not user-defined

- Localhost probes are hardcoded in `LocalhostProbeService` (`:8080`, `:3000`, `:9091`).
- Settings expose refresh/debounce toggles but no service registry CRUD.

Impact:

- Localhost page cannot represent user-specific service fleets.

## Settings-to-Runtime Wiring Gaps

The settings store is comprehensive, but many toggles are currently UI/store-only and do not change production behavior outside settings screens.

Notable examples:

- Agent monitoring toggles and refresh controls.
- Closed-state visibility toggles for multiple domains.
- Debug/diagnostic overlays.
- Gesture tuning and enablement controls (beyond partial shell close behavior).
- Launch-at-login.

## Integration Gaps

### Notion sync

- Current Notion path performs a connectivity check (`/v1/users/me`) only.
- No habits/learnings write-back or read-sync model exists yet.

### Agent monitoring

- No observer adapters yet for Codex/Claude/OpenClaw.
- Agent page remains placeholder.

### Notifications/OpenClaw/Financial

- No domain/runtime implementations yet.
- No adapters, no event model consumers, no page-level tests.

## Test Coverage Gaps

### Covered well

- Shell geometry/view model/windowing baseline.
- Core scaffolding primitives (event bus, persistence, registry, permissions, diagnostics, runtime start).

### Missing or thin

- Media runtime behavioral tests.
- HUD camera/screen-capture service tests.
- Calendar quick-create and permission-transition edge-paths.
- Localhost probe configuration and debounce behavior.
- Focus persistence lifecycle tests (currently not possible due to missing persistence path).
- Placeholder-page replacement readiness tests (notifications/agents/openclaw/financial).
- UI tests are limited to basic launch/settings/tab smoke paths.

## Priority Execution Order

1. Complete adapter-driven runtime wiring:
   - register production adapters, move direct service calls behind adapter contracts.
2. Introduce event-bus consumer flow:
   - adapter -> event bus -> state composition -> shell snapshot.
3. Implement next pages in order:
   - Notifications -> Agents -> OpenClaw -> Financial.
4. Persist focus session history and wire analytics snapshots.
5. Replace hardcoded localhost probe definitions with settings-backed service registry.
6. Expand test coverage for media/HUD/runtime permission/degraded modes.

## Notes

- Shell foundation is strong and production-like.
- Current bottleneck is runtime architecture convergence, not shell polish.
