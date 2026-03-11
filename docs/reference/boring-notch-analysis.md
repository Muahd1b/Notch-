# Boring Notch Reference Analysis

Date: March 9, 2026
Status: Reference

## Purpose

This document captures how Boring Notch works at a product and implementation level based on its public repository and README. It separates confirmed implementation details from product-level inference so it can be reused as input for `Notch-`.

## Executive Summary

Boring Notch is not built on a special Apple notch API. It is a SwiftUI app that uses custom AppKit windows to draw a fake, animated notch-shaped interface at the top center of one or more displays. The closed state is sized to match the physical notch on supported MacBook displays, and the open state expands into a larger overlay panel.

The app mixes public macOS APIs with higher-risk system integrations:

- public UI/windowing via SwiftUI, `NSPanel`, `NSScreen`, EventKit, AVFoundation, IOKit
- Apple Events / AppleScript for Apple Music and Spotify control
- private or brittle integrations for MediaRemote, brightness control, SkyLight window delegation, and lock-screen behavior
- an unsandboxed XPC helper for privileged or sensitive system interactions

## Confirmed Architecture

### 1. App shell

Boring Notch starts as a SwiftUI app with a menu bar extra and an `AppDelegate` that manages the overlay windows.

Key source:

- `MenuBarExtra`, settings, updater, and app entry:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotchApp.swift

### 2. Window model

The actual notch UI is rendered inside custom `NSPanel` windows, not inside a standard SwiftUI window scene.

Confirmed behavior:

- one overlay window for the selected screen in single-display mode
- one overlay window per screen in all-displays mode
- each window hosts `ContentView()` through `NSHostingView`
- each window is borderless, non-activating, floating, transparent, and centered at the top of the screen

Key sources:

- window creation and positioning:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotchApp.swift
- custom window class:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift

### 3. Notch geometry

The closed notch geometry is derived from the real display cutout when available.

Confirmed logic:

- width is computed from `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`
- height is computed from either:
  - `safeAreaInsets.top`
  - menu bar height
  - custom user preference for non-notched displays
- open size is fixed to `640 x 190`

Key source:

- sizing constants and notch math:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/sizing/matters.swift

## Windowing and Layering Details

The custom panel is configured to behave like an overlay, not a normal app window.

Confirmed settings:

- `isFloatingPanel = true`
- `isOpaque = false`
- `backgroundColor = .clear`
- `level = .mainMenu + 3`
- `collectionBehavior` includes:
  - `.fullScreenAuxiliary`
  - `.stationary`
  - `.canJoinAllSpaces`
  - `.ignoresCycle`
- `canBecomeKey` and `canBecomeMain` are both `false`

Implication:

This is the standard overlay-window pattern for notch-adjacent macOS apps. The app visually integrates with the menu bar area by staying above normal app content while avoiding full ownership of focus.

Key source:

- overlay panel implementation:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift

## Interaction Model

### Hover and open/close state

Each display window has a `BoringViewModel` that owns the local notch state:

- `closed`
- `open`

Confirmed behavior:

- `open()` switches to `openNotchSize`
- `close()` restores the computed closed notch size
- opening the notch also forces a music refresh

Key source:

- per-window state model:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/models/BoringViewModel.swift

### Drag-to-shelf behavior

Boring Notch listens globally for drag gestures and opens the shelf when valid dragged content enters the notch region.

Confirmed behavior:

- monitors global `leftMouseDown`, `leftMouseDragged`, and `leftMouseUp`
- checks the drag pasteboard for supported content types:
  - file URLs
  - URLs
  - strings
- computes a notch region near the top-center of each display
- triggers shelf opening when dragged content enters that region

Key sources:

- drag monitor:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/DragDetector.swift
- detector setup and shelf trigger:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotchApp.swift

### Shortcuts and transient HUDs

The shared `BoringViewCoordinator` manages transient UI such as sneak peeks and temporary expanded panels.

Confirmed behavior:

- keyboard shortcuts can toggle sneak peek and notch open state
- short-lived overlays are coordinated globally
- HUD replacement states feed into the same coordinator

Key source:

- global coordinator:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/BoringViewCoordinator.swift

## Settings System

### Settings window model

Boring Notch uses a dedicated `SettingsWindowController` with a standard macOS `NSWindow`, not a custom notch overlay.

Confirmed behavior:

- singleton settings window controller
- titled, closable, miniaturizable, resizable window
- SwiftUI settings content hosted through `NSHostingView`
- activation policy changes to `.regular` while settings is shown
- activation policy returns to `.accessory` after the window closes

Implication:

The shell and the settings surface are separate concerns. The notch shell launches settings, but does not try to become the settings surface.

Key sources:

- settings window controller:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Settings/SettingsWindowController.swift
- settings root view:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Settings/SettingsView.swift

### Configuration persistence

Most persistent configuration lives in a single typed `Defaults.Keys` registry.

Confirmed settings areas:

- general behavior
- hover and haptics
- notch sizing
- appearance and lighting
- gestures
- media and HUD
- shelf
- calendar
- advanced settings such as custom accent color

Implication:

This typed key registry is one of the strongest reusable patterns in the application. It keeps settings discoverable and makes feature flags explicit.

Key source:

- typed defaults registry:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/models/Constants.swift

### Settings access from the shell

Boring Notch exposes settings from multiple places, including directly from the open-notch header.

Confirmed access surfaces:

- `MenuBarExtra`
- notch root context menu
- open-notch extras menu
- open-notch header gear button when `settingsIconInNotch` is enabled

Implication:

The important pattern is not “settings in the notch.” The important pattern is “settings reachable from the notch shell.”

Key sources:

- menu bar and app-level access:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotchApp.swift
- shell context menu and shell structure:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/ContentView.swift
- header gear action:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringHeader.swift
- extras menu settings button:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringExtrasMenu.swift

## Feature Implementations

### Music

Boring Notch uses multiple backends depending on the chosen media source.

Confirmed implementations:

- `NowPlayingController`
  - uses private `MediaRemote.framework`
  - launches a bundled `mediaremote-adapter` process
  - parses JSON-line updates for playback state
- `AppleMusicController`
  - uses AppleScript and distributed notifications from the Music app
- `SpotifyController`
  - uses AppleScript and Spotify distributed notifications
- `MusicManager`
  - normalizes data into one shared playback model
  - fetches lyrics, including fallback web lookup via `lrclib.net`

Key sources:

- media orchestration:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/MusicManager.swift
- now playing backend:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/MediaControllers/NowPlayingController.swift
- Apple Music backend:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/MediaControllers/AppleMusicController.swift
- Spotify backend:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/MediaControllers/SpotifyController.swift

### Calendar and reminders

Confirmed implementation:

- EventKit-backed
- loads event calendars and reminder lists
- reacts to `EKEventStoreChanged`

Key source:

- calendar manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/CalendarManager.swift

### Camera / mirror

Confirmed implementation:

- AVFoundation capture session
- `AVCaptureVideoPreviewLayer`
- supports built-in and external cameras

Key source:

- webcam manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/WebcamManager.swift

### Battery and charging activity

Confirmed implementation:

- IOKit power-source notifications
- observes charging state, power source, low power mode, current capacity, max capacity, and time to full charge

Key source:

- battery manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/BatteryActivityManager.swift

### HUD replacement

Confirmed implementation:

- installs a CGEvent tap for system-defined events
- intercepts volume, mute, screen brightness, and keyboard backlight keys
- displays custom notch HUD states instead of relying on the default system HUD path

Key source:

- media key interceptor:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/MediaKeyInterceptor.swift

## Permissions and Risk Profile

### Main app entitlements

The main app requests access to:

- camera
- calendars
- Apple Events automation
- user-selected file access
- client and server networking

Key source:

- main app entitlements:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotch.entitlements

### XPC helper

Boring Notch ships an XPC helper that is explicitly not sandboxed.

Confirmed responsibilities:

- accessibility authorization checks and prompting
- keyboard brightness read/write through private CoreBrightness access
- screen brightness read/write through DisplayServices and IOKit

Key sources:

- helper entitlements:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements
- helper implementation:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/BoringNotchXPCHelper/BoringNotchXPCHelper.swift
- client bridge:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/XPCHelperClient/XPCHelperClient.swift

### Private and brittle integrations

The following parts are higher risk from a maintenance and distribution perspective:

- `MediaRemote.framework`
- `SkyLight` window delegation and undelegation
- DisplayServices brightness calls
- CoreBrightness keyboard backlight calls
- lock-screen-specific behavior dependent on SkyLight

Key sources:

- MediaRemote usage:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/MediaControllers/NowPlayingController.swift
- SkyLight usage:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift

## Product-Level Inference

The product strategy appears to be:

- make the notch a persistent top-of-screen utility surface
- turn multiple disconnected macOS signals into one unified ambient interface
- favor “delight” and visibility over strict App Store-safe minimalism

This inference is supported by the mix of:

- media live activity
- shelf / drag-and-drop affordances
- camera mirror
- HUD replacement
- lock-screen presence

but it is still inference rather than an explicit statement from the codebase.

## Reusable Patterns for Notch-

These patterns are worth reusing:

- per-display overlay windows instead of a single global window
- real-notch-aware closed geometry
- shared coordinator plus per-screen view model
- modular feature managers with one normalized state model per domain
- explicit separation between safe/public features and privileged features

These patterns should be treated cautiously:

- private frameworks for media and brightness
- unsandboxed helper architecture unless clearly justified
- lock-screen window delegation through private APIs

## Recommended Takeaways for Notch-

### Foundation to keep

- overlay `NSPanel` architecture
- real notch sizing via `NSScreen`
- per-display support
- modular manager architecture
- strong transient-state coordination for mini live activities

### Foundation to avoid in V1

- hard dependency on private frameworks
- lock-screen presence as a baseline feature
- full HUD replacement as a first milestone
- unsandboxed helper as a prerequisite for core product value

### Better product direction

For `Notch-`, the strongest path is:

1. build a public-API-first core that already feels premium
2. define advanced system integrations as a separate capability tier
3. keep the architecture ready for privileged extensions without making them mandatory for product-market fit

## Source Index

- README:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/README.md
- App entry and window orchestration:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotchApp.swift
- Global coordinator:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/BoringViewCoordinator.swift
- Per-window model:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/models/BoringViewModel.swift
- Sizing:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/sizing/matters.swift
- Custom panel:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift
- Drag detection:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/DragDetector.swift
- Media key interception:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/MediaKeyInterceptor.swift
- Music manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/MusicManager.swift
- Media controllers:
  - https://github.com/TheBoredTeam/boring.notch/tree/main/boringNotch/MediaControllers
- Calendar manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/CalendarManager.swift
- Webcam manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/WebcamManager.swift
- Battery manager:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/managers/BatteryActivityManager.swift
- Main app entitlements:
  - https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/boringNotch.entitlements
- XPC helper:
  - https://github.com/TheBoredTeam/boring.notch/tree/main/BoringNotchXPCHelper
- XPC client:
  - https://github.com/TheBoredTeam/boring.notch/tree/main/boringNotch/XPCHelperClient
