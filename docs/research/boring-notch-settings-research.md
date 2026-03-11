# Boring Notch Settings System Research

Date: March 9, 2026
Status: Reference

## Purpose

This document captures how Boring Notch handles settings, configuration persistence, shell access, and the shell-level shape and haptic primitives that create its product feel. The goal is to identify the exact upstream implementation surfaces that should be ported into `Notch-`.

## Executive Summary

Boring Notch does not implement settings as another notch overlay. It uses a normal macOS settings window and makes that window reachable from multiple surfaces:

- the menu bar extra
- the notch context menu
- the open-notch extras menu
- the open-notch header symbol bar through a gear button

That distinction matters. The premium feel comes mostly from the shell layer, not from a custom settings container. For `Notch-`, the required model is:

- a regular settings window for full configuration
- a typed configuration system with one central key registry
- live propagation from settings to the shell
- mandatory settings access from the notch header symbol bar

## Confirmed Boring Notch System Shape

### Settings window architecture

Boring Notch uses a singleton `SettingsWindowController` that owns a standard `NSWindow`.

Confirmed behavior:

- window size starts around `700 x 600`
- standard titled, closable, miniaturizable, resizable window
- SwiftUI content is hosted with `NSHostingView`
- app activation temporarily switches to `.regular` while the settings window is active
- the app returns to `.accessory` when settings closes

Implication:

The product does not treat settings as a floating shell panel. It treats settings as a regular app surface with normal focus behavior.

Key sources:

- `components/Settings/SettingsWindowController.swift`
- `components/Settings/SettingsView.swift`

### Settings information architecture

The main settings UI is a large SwiftUI `NavigationSplitView` with sidebar-driven sections.

Confirmed groups include:

- General
- Appearance
- Media
- Calendar
- HUD
- Battery
- Shelf
- Shortcuts
- Advanced
- About

Implication:

The settings surface is broad and desktop-native. It is not compressed into the notch itself. The notch only acts as a launcher and as a place where settings affect live behavior.

For the per-page contents and control groupings that should be copied later, use the [Boring Notch settings catalog](../reference/boring-notch-settings-catalog.md).

### Persistence model

Boring Notch centralizes most persistent configuration in `Defaults.Keys`.

Confirmed characteristics:

- one typed key registry
- strong defaults for most behavior
- custom serializable enums and structs for richer settings
- settings read directly across shell and feature code

Examples of actual key categories:

- hover and behavior
- haptics
- notch height and non-notch fallback height
- appearance flags such as shadow, lighting, corner radius scaling
- settings icon visibility in the notch
- shelf and calendar configuration
- media controller and HUD options

Implication:

The strongest part of their settings system is the typed registry. The weakest part is that some runtime state and settings concerns are mixed across singletons, `Defaults`, `@AppStorage`, and notifications.

Key source:

- `models/Constants.swift`

### Runtime propagation

Boring Notch uses a mixed runtime propagation model:

- `Defaults` reads in feature and shell code
- `Defaults.publisher(...)` for some reactive feature wiring
- `@AppStorage` inside coordinators for selected state
- `NotificationCenter` fan-out for display and shell changes

Implication:

The app updates live, but the design is only partially centralized. `Notch-` should keep the live-update behavior while using a cleaner `SettingsStore` layer.

Key sources:

- `BoringViewCoordinator.swift`
- `boringNotchApp.swift`
- `models/BoringViewModel.swift`

## Settings Access Pattern

### Header symbol bar access

Boring Notch exposes settings from the open-notch header through a gear button when `settingsIconInNotch` is enabled.

Important details:

- the gear lives in the header action cluster
- the button uses the same visual token as other shell controls
- the action opens the full settings window, not an inline mini-settings panel

This is the closest match to the requested `Symboleiste` behavior for `Notch-`.

Key source:

- `components/Notch/BoringHeader.swift`

### Other access surfaces

Boring Notch also exposes settings from:

- the menu bar extra
- the notch root context menu
- the extras menu inside the open notch

Key sources:

- `boringNotchApp.swift`
- `ContentView.swift`
- `components/Notch/BoringExtrasMenu.swift`

### Recommendation for `Notch-`

`Notch-` should make settings reachable from:

- the notch header symbol bar as a required entry point
- the menu bar app as a fallback or secondary entry point
- a shell context menu later if it proves useful

The symbol-bar entry should be treated as mandatory, not optional.

The concrete upstream source files for this are listed in [Boring Notch source map](../reference/boring-notch-source-map.md).

## Page-Level Logic Inventory

The future-copy settings logic that matters most for `Notch-` is:

- General page gesture controls with `Beta` badge
- Calendar page toggle group plus source-selection lists
- HUD page split between open-notch and closed-notch behavior
- Battery page compact grouped toggle layout

These are now tracked separately in [Boring Notch settings catalog](../reference/boring-notch-settings-catalog.md) so they can be ported later without re-reading the entire repo.

## Shape System Findings

The Boring Notch shell feel comes from a small set of consistent shape primitives.

Confirmed shell cues:

- black-filled outer shell
- asymmetric notch radii
- default `NotchShape` corner radii of top `6` and bottom `14`
- larger opened radii driven by dedicated constants
- small capsule control buttons in the header
- larger rounded-rectangle action tiles in the extras menu
- real-notch mask in the center of the open header region

The important lesson is not the exact pixel values alone. It is the consistency:

- one outer shell language
- one control-button language
- one expanded-card language

Key sources:

- `components/Notch/NotchShape.swift`
- `sizing/matters.swift`
- `components/Notch/BoringHeader.swift`
- `components/Notch/BoringExtrasMenu.swift`
- `ContentView.swift`

## Haptic Findings

The distinctive haptic behavior is also shell-led, not settings-window-led.

Confirmed pattern:

- haptics are gated by a user setting
- SwiftUI sensory feedback is used for shell interactions
- haptics are sparse and tied to meaningful interaction resolution

Implication:

For `Notch-`, the correct target is not constant vibration. It is one or two deliberate confirmation events around:

- open resolution
- peek resolution
- future module completion events such as timer completion

Key sources:

- `ContentView.swift`
- `models/Constants.swift`

## Recommended `Notch-` Architecture

### Settings system

Build the `Notch-` settings system as:

- `SettingsWindowController`
- `SettingsView`
- `SettingsStore`
- `AppSettingsKey` registry or equivalent typed settings namespace
- live observation layer so shell and adapters update without restart where possible

### Shell access

The first settings access path should be:

- a gear action in the notch header symbol bar

Secondary access should be:

- menu bar

Deferred access can be:

- shell context menu
- extras menu

### What to copy structurally

These Boring Notch traits should be ported directly:

- standard macOS settings window for the full configuration surface
- header symbol-bar gear launching the settings window
- typed central settings registry
- live shell updates when settings change
- shell shape built from a small, consistent shape language
- sparse confirmation haptics attached to meaningful state changes

### What not to copy literally

Do not carry over:

- Boring Notch product naming
- Boring Notch feature categories that do not belong to `Notch-`
- private or brittle implementation tricks unrelated to the shell/settings system

## Phase Impact For `Notch-`

### Phase 0

Phase 0 should include:

- a reserved symbol-bar settings action in the notch shell
- a placeholder or early settings-window launch path
- initial shell shape tokens
- initial haptic event mapping

### Phase 1

Phase 1 should include:

- full typed settings registry
- full settings window controller and root settings view
- live propagation from settings to shell
- shell categories for hover, haptics, display targeting, and module visibility

### Validation

Dedicated testing should cover:

- settings window lifecycle
- symbol-bar settings launch
- persistence defaults and migrations
- live shell updates after settings changes
- haptics enabled and disabled paths

## Bottom Line

The right way to emulate Boring Notch here is:

- copy the settings system shape
- copy the access model
- copy the shell-level design primitives
- copy the sparse haptic philosophy

The wrong way is:

- trying to turn the notch itself into the full settings surface
- spreading config keys ad hoc across the codebase
- copying Boring Notch visual identity instead of reproducing the interaction system quality
