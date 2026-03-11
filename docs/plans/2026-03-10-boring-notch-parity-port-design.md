# Boring Notch Parity Port Design

Date: March 10, 2026
Status: Active (Phase 0 parity baseline)

## Purpose

This design defines the first implementation slice for exact Boring Notch shell and settings parity in `Notch-`.

The target is not approximate inspiration. The target is direct structural parity for:

- shell shape language
- shell sizing and open-state geometry
- shell header layout and symbol-bar controls
- shell haptic trigger timing
- settings window shell
- settings view layout and grouped form styling
- settings access from the shell symbol bar
- typed settings registry shape

`Notch-` will adapt only the sidebar labels, settings sections, and feature-specific fields to its own domains.

## Approved Approach

Use a structural port with selective wholesale upstream transplants.

This means:

- pull exact upstream shell and settings surfaces into local code
- keep the imported surface controlled and local to the repo
- replace only the feature-specific content and settings categories

This avoids a by-eye recreation while also avoiding a full application fork.

## Upstream Port Set

Port these upstream Boring Notch surfaces first:

- `NotchShape`
- sizing/constants
- shell header
- `SettingsWindowController`
- `SettingsView`
- typed settings registry

These sources are pinned in [Boring Notch source map](../reference/boring-notch-source-map.md).

## Local Implementation Shape

Add these local surfaces:

- `Notch-/Shell/UI/NotchShape.swift`
- `Notch-/Shell/Core/ShellSizing.swift`
- `Notch-/Shell/UI/ShellHeaderView.swift`
- `Notch-/Settings/Windowing/SettingsWindowController.swift`
- `Notch-/Settings/UI/SettingsView.swift`
- `Notch-/Settings/Store/AppSettings.swift`

Refactor these existing files:

- `Notch-/Shell/UI/ShellRootView.swift`
- `Notch-/Shell/Core/ShellViewModel.swift`
- `Notch-/Shell/Windowing/ShellWindowController.swift`
- `Notch-/Shell/Core/HapticsService.swift`
- `Notch-/Shell/Core/ShellStatusSnapshot.swift`

## Settings Adaptation Rules

Keep exact parity for:

- window dimensions
- `NavigationSplitView` shell
- sidebar column width
- grouped form layout
- control sizing
- visual grouping
- activation-policy behavior
- shell gear access behavior

Replace immediately:

- sidebar labels
- settings sections
- form copy
- feature fields

Target `Notch-` settings sections:

- `General`
- `Appearance`
- `Calendar`
- `Agents`
- `Localhost`
- `Habits`
- `Learnings`
- `Focus`
- `Advanced`
- `About`

## Data And State

Introduce a typed settings registry in this slice so the ported settings shell has a stable local state surface.

First-pass keys should cover:

- menu bar icon visibility
- launch at login placeholder
- show on all displays
- preferred display
- automatically switch displays
- notch height mode for notch displays
- notch height mode for non-notch displays
- open notch on hover
- enable haptics
- remember last tab
- hover delay
- settings icon visibility in symbol bar

Later module-specific settings can be added under the same registry.

## Interaction And Motion

The shell should port:

- asymmetric notch shape
- header action capsule styling
- hover-open timing
- close-on-hover-exit behavior
- open and settle haptic triggers
- shell shadow and open-state geometry language

The content inside the shell remains `Notch-`-specific.

## Testing

Targeted validation after this slice:

- shell header renders in open state
- settings gear appears in the symbol bar
- settings gear opens the settings window
- settings window uses the expected base dimensions and split layout shell
- shell hover/open/close still works after the refactor
- shell haptics still fire on open and settle transitions
- UI tests no longer depend on accidental hover timing to reach the open state

## Implementation Order

1. Add shell primitives: `NotchShape`, sizing constants, shell header view.
2. Refactor shell root/open state to use the new header and shape language.
3. Add typed settings registry.
4. Add `SettingsWindowController`.
5. Add `SettingsView` with `Notch-` sidebar labels and placeholder section content.
6. Wire the gear button from the shell header to the settings window.
7. Update tests and add targeted settings-launch coverage.

## Post-Parity Page Rollout Plan

This section links the parity slice to the page implementation needs defined in the PRD.

### Stage 1: Core spine before page depth

- Implement event bus, persistence, adapter registry, and permissions manager.
- Keep page surfaces thin until normalized contracts are stable.

### Stage 2: Daily-value pages

- Calendar: right-side timeline and left-side create/reminder actions.
- Localhost: service health plus RAM usage where confidence is sufficient.
- Focus/Habits/Learnings: local-first models and progression metrics.
- Home: summarized KPIs from available page modules.

### Stage 3: Communication and agent pages

- Notifications ingestion for WhatsApp, Discord, Instagram, Telegram.
- Media controls with Spotify/Apple Music provider abstraction.
- Agents status model with required statuses: `ongoing`, `idle`.
- OpenClaw split panel: chat + metrics.

### Stage 4: Advanced pages

- HUD camera and stream-display controls.
- Financial board with per-business profit, MRR, revenue, and trends.

### Page-level acceptance requirements

- Every page must define degraded mode behavior before implementation starts.
- Every page must map to at least one dedicated adapter/domain test suite.
- No page integration may block shell rendering or shell interaction quality.

## Non-Goals For This Slice

- module adapters
- event bus
- persistence layer
- real Calendar, agent, localhost, habits, learning, or focus integration logic
- full Boring Notch feature parity outside shell/settings behavior

## Residual Risks

- Direct upstream ports may pull in more assumptions than the current `Notch-` shell supports.
- The exact motion feel may require a second pass after the first structural transplant.
- The repo is still in an early dirty state, so this work should avoid broad unrelated cleanup while implementing the parity slice.
