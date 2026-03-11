# Boring Notch Source Map

Date: March 10, 2026
Status: Reference
Upstream: `TheBoredTeam/boring.notch`
Pinned upstream commit: `768b9334a362e93a6f73bf6183ff3d607c3da567`

## Purpose

This document pins the exact upstream Boring Notch source files that should be used as the implementation reference for the `Notch-` shell, haptics, settings system, and shell settings access.

This is the "exact means exact" source map for the current build direction.

Use these files as the starting point for structure, behavior, visual primitives, and settings access. Adapt only where `Notch-` needs different integrations or local architecture.

## Exact Upstream Files

### Settings window and settings UI

- `boringNotch/components/Settings/SettingsWindowController.swift`
- `boringNotch/components/Settings/SettingsView.swift`

What to mirror in `Notch-`:

- singleton `SettingsWindowController`
- standard titled `NSWindow`
- `NavigationSplitView` settings shell
- sidebar category structure
- toolbar-level quit action in General
- activation policy handoff between accessory and regular app mode
- grouped per-page sectioning such as General, Calendar, HUDs, and Battery
- `Beta` badges on section headers where upstream uses them
- colored source-selection rows for Calendar and Reminders

Adapt for `Notch-`:

- replace Media, HUD, Battery, Shelf, and other Boring Notch feature sections with Codex, Claude, OpenClaw, localhost, habits, learnings, Pomodoro, and related shell settings

Detailed page inventory is tracked in [Boring Notch settings catalog](./boring-notch-settings-catalog.md).

### Shell header and settings gear in the symbol bar

- `boringNotch/components/Notch/BoringHeader.swift`

What to mirror in `Notch-`:

- right-aligned capsule action cluster in the open shell header
- gear button visual treatment
- settings launch from the shell symbol bar
- conditional item layout in the header action strip

### Shape language and shell geometry constants

- `boringNotch/components/Notch/NotchShape.swift`
- `boringNotch/sizing/matters.swift`

What to mirror in `Notch-`:

- asymmetric `NotchShape`
- closed corner radii defaults
- opened corner radii scaling
- open notch baseline size constants
- closed notch sizing derived from `NSScreen` notch geometry

### Settings registry and default keys

- `boringNotch/models/Constants.swift`

What to mirror in `Notch-`:

- one central typed defaults registry
- grouped settings keys by domain
- shell-facing keys for hover, haptics, display targeting, notch sizing, and settings icon visibility

Adapt for `Notch-`:

- remove media-specific, HUD-specific, battery-specific, and shelf-specific keys that are not part of the target product
- replace them with keys for agent monitoring, localhost probes, habits, learnings, Pomodoro, and module ordering

### Shell view flow and haptic trigger points

- `boringNotch/ContentView.swift`
- `boringNotch/models/BoringViewModel.swift`

What to mirror in `Notch-`:

- hover-open timing behavior
- close-on-hover-exit behavior
- shell open and close animation flow
- shell-level haptic trigger points
- context-menu settings access fallback
- shape clipping, shadow behavior, and open/closed composition split

Adapt for `Notch-`:

- replace media and battery content with `Notch-` domains
- preserve the shell mechanics even where the content differs

## Required Carryover For `Notch-`

The current product direction requires direct upstream reference for:

- shell UI structure
- shell motion rhythm
- shell haptic timing
- settings window structure
- settings access model
- shell header gear affordance

## Allowed Adaptation Surface

Adapt only these areas without treating the result as drift:

- integration-specific content and settings sections
- product naming and copy
- module cards and detail panes
- architecture seams needed for local-first adapters and the planned event bus/store

## Implementation Note

When implementing these areas in `Notch-`, prefer:

1. fetching from the pinned upstream files above
2. porting the relevant structure into the local `Shell/` and future `Settings/` code
3. adapting only the parts that bind to `Notch-` modules and data sources

If the local implementation intentionally diverges from one of these upstream files, record the divergence in the relevant architecture or current-state document.
