# Notch- Phase 0 Shell Research

Date: March 9, 2026
Status: Active reference
Phase: Phase 0, shell foundation

> [!TIP]
> This document translates the Phase 0 section of the [build plan](../architecture/build-plan.md) into implementation-ready guidance. The current implementation status is tracked in [current-state](../architecture/current-state.md).

## Purpose

This document defines the recommended technical starting point for the first implementation phase of `Notch-`.

Phase 0 should answer one question:

Can `Notch-` deliver a premium, notch-native shell before any deep integrations exist?

The answer should be proven with:

- a stable top-centered shell window
- real notch geometry handling
- closed, peek, and open presentation states
- calm animation and haptic feedback
- dedicated shell tests after every shell edit

## Research Summary

The best Phase 0 stack is:

- Xcode macOS app target as the delivery vehicle
- SwiftUI for shell views
- AppKit `NSPanel` for the notch window
- `NSHostingView` to embed SwiftUI into the panel
- `NSScreen` safe-area geometry to compute real notch dimensions
- `NSHapticFeedbackManager` for supported macOS haptic feedback
- `XCTest` and UI tests for dedicated post-edit validation

The shell should stay public-API-first in Phase 0.

That means:

- do not use private SkyLight behavior
- do not use process tricks to keep the shell alive across every edge case
- do not copy Boring Notch assets or exact product identity

The first implementation should also stay runnable-first.

That means:

- start with a macOS app target you can launch locally
- add unit and UI test targets immediately
- delay package extraction until after the shell is proven

## Recommended Shell Architecture

### Recommended app shape

Use a SwiftUI macOS app target as the application entry point, but let AppKit own the shell window lifecycle.

Recommended ownership:

- `NotchApp`
  - app entry
- `ShellCoordinator`
  - creates and manages shell windows
- `ShellWindowController`
  - owns one `NSPanel`
- `ShellViewModel`
  - owns shell presentation state
- `ShellGeometryResolver`
  - computes notch and fallback geometry
- `HapticsService`
  - plays supported haptic events

This keeps the shell implementation independent from later adapters.

For Phase 0, prefer this over a package-first setup because it gets a real shell on screen faster and makes hardware validation possible earlier.

### Why `NSPanel`

`NSPanel` is the right base window type for Phase 0 because the shell is utility-like, always-ambient, and should avoid behaving like a normal document window.

Recommended panel characteristics:

- borderless
- non-opaque
- background clear
- non-activating
- not key by default
- not main by default
- visible across Spaces
- allowed alongside fullscreen apps

This exact combination is an inference from Apple window APIs plus public notch implementations like DynamicNotchKit and Boring Notch. Apple documents the individual window flags, while the product-specific combination has to be assembled by the app.

## Window Configuration Recommendation

Recommended Phase 0 panel setup:

- `styleMask`: `borderless` + `nonactivatingPanel`
- `isOpaque = false`
- `backgroundColor = .clear`
- `hasShadow = false` initially
- `level`: start with a high utility-style level such as `statusBar` or `mainMenu`
- `collectionBehavior`:
  - `canJoinAllSpaces`
  - `fullScreenAuxiliary`
  - `stationary`
  - `ignoresCycle`

Recommended behavior:

- `canBecomeKey = false`
- `canBecomeMain = false`
- do not steal focus on hover or automatic transitions

One public reference implementation allows key-window behavior, but that is not the right default for `Notch-`. Phase 0 should optimize for ambient overlay behavior and focus safety first.

## Geometry Strategy

### Source of truth

The notch shell should derive its geometry from `NSScreen`, not from hardcoded dimensions.

Use:

- `safeAreaInsets`
- `auxiliaryTopLeftArea`
- `auxiliaryTopRightArea`
- `visibleFrame`
- `frame`

### Recommended detection model

Treat a screen as notched when:

- `safeAreaInsets.top > 0`
- and both auxiliary top areas are available

Recommended normalized screen model:

```swift
struct ScreenGeometry {
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaInsets: NSEdgeInsets
    let auxiliaryTopLeftWidth: CGFloat?
    let auxiliaryTopRightWidth: CGFloat?
}
```

### Recommended notch calculations

For a notched screen:

- `notchHeight = safeAreaInsets.top`
- `notchWidth = frame.width - auxiliaryTopLeftWidth - auxiliaryTopRightWidth`
- `notchOriginX = frame.midX - notchWidth / 2`
- `notchOriginY = frame.maxY - notchHeight`

For a non-notched screen fallback:

- `fallbackHeight = frame.maxY - visibleFrame.maxY`
- `fallbackWidth` should be product-defined, not hardware-derived
- use a centered top anchor so the shell still reads as notch-native

This matches the practical pattern used in public notch projects and lines up with Apple's safe-area model for built-in camera housings.

### Window anchoring

The shell panel should be anchored to the selected screen's top center.

Recommended rule:

- the panel frame should be recalculated from the active shell size
- the panel's `x` should stay centered on the screen
- the panel's `y` should stay attached to the top edge of the screen

This allows the shell size to change while the visual anchor remains stable.

## Multi-Display and Environment Changes

Phase 0 should not fully optimize every display topology, but it should be architected so display changes are not a rewrite later.

Recommended Phase 0 behavior:

- support one selected display first
- keep `displayID` or equivalent identity in the shell model from day one
- observe screen-parameter changes and recalculate geometry
- observe Spaces changes and verify the panel remains visible where expected
- re-anchor if the shell moves to another screen

Relevant system events to watch:

- `NSApplication.didChangeScreenParametersNotification`
- `NSWindow.didChangeScreenNotification`
- `NSWorkspace.activeSpaceDidChangeNotification`

## Shell State Model

Keep shell presentation state separate from geometry and separate from later module data.

Recommended Phase 0 presentation enum:

```swift
enum ShellPresentationState: Equatable {
    case closed
    case peek(PeekReason)
    case open(OpenReason)
}
```

Recommended supporting state:

- hover tracking
- pinned-open state
- transition-in-flight guard
- reduced-motion mode
- haptics enabled / disabled

Keep the state machine explicit.

Do not let hover timers, panel frame logic, and view transitions all mutate each other ad hoc.

## SwiftUI and AppKit Composition

Use SwiftUI for shell visuals and AppKit for the host window.

Recommended pattern:

- `NSPanel` owns an `NSHostingView`
- `NSHostingView` renders `ShellRootView`
- `ShellRootView` receives a single shell view model

This keeps most of the visual shell iteration in SwiftUI while leaving panel control where AppKit is stronger.

Recommended split:

- AppKit owns:
  - panel lifecycle
  - frame changes
  - screen anchoring
  - focus behavior
- SwiftUI owns:
  - shape and masking
  - content layout
  - visual transitions
  - reduced-motion adaptation

## Animation Recommendation

Phase 0 should directly port the Boring Notch shell interaction and animation model for the shell layer, then adapt the content that lives inside it.

Recommended motion principles:

- anchor the shell visually to the hardware notch
- expand primarily downward, not away from the notch
- use one transition rhythm for closed to peek to open
- avoid stacked or competing micro-animations
- let content animate inside a stable outer shell when possible

Recommended implementation split:

- use AppKit frame animation only for panel size and placement changes
- use SwiftUI animation for internal content and shape transitions

This reduces the risk of geometry drift during transitions.

## Boring Notch Shape And Access Findings

The Boring Notch shell feel comes from a tight shell language, not from a complex settings container.

Relevant findings:

- it uses a dedicated `NotchShape` with asymmetric radii instead of a generic rounded rectangle
- its header uses small black capsule controls for shell actions
- its extras menu uses a larger rounded-rectangle card language for secondary actions
- settings is reachable from the open shell header through a gear button in the symbol bar
- the gear opens a regular macOS settings window, not an inline notch settings mode

Phase 0 implication:

`Notch-` should port the symbol-bar settings affordance immediately from the upstream implementation. That keeps the shell architecture aligned with the intended interaction model from the start.

## Haptics Recommendation

Use the upstream Boring Notch shell haptic trigger model as the interaction reference and map it onto `NSHapticFeedbackManager` in `Notch-`.

Recommended haptic events:

- open snap
- successful drag snap later if drag interactions remain
- peek resolution
- timer or completion event later when modules exist

Phase 0 should keep haptics minimal:

- one confirmation for opening
- one confirmation for a meaningful resolved state
- no repeated idle haptics

Graceful degradation rules:

- if no supported hardware exists, the shell remains fully usable
- haptics should be a feedback layer, not a state signal dependency

## Public Reference Implementation Takeaways

### DynamicNotchKit

DynamicNotchKit is useful as a public reference because it:

- uses `NSPanel`
- computes notch geometry from `NSScreen`
- separates notch state from view content
- supports notched and non-notched displays

Useful takeaways:

- keep notch geometry in screen extensions or a dedicated resolver
- keep shell state compact and explicit
- treat non-notched Macs as first-class fallback targets

### Boring Notch

Boring Notch is the direct shell and settings implementation reference for `Notch-` Phase 0 and early Phase 1.

Useful takeaways:

- the shell should feel attached to the hardware cutout
- a borderless ambient panel model works well
- notch width and height should come from real screen geometry
- the open shell should expose a small header action cluster
- settings should be launchable from the shell header, but the full settings surface should remain a regular app window
- a small shape vocabulary creates more cohesion than many one-off container styles
- haptics should be sparse and tied to resolved state changes

Do not carry forward into Phase 0:

- private SkyLight usage
- private-framework-dependent behavior
- product-specific branding or visual identity

## Dedicated Test Strategy For Phase 0

After any shell edit, run dedicated tests for the shell subsystem.

Phase 0 should not rely on visual confidence alone.

The recommended target layout is:

- one macOS app target
- one unit test target
- one UI test target

### 1. Geometry unit tests

Extract notch math into a pure geometry resolver and test it directly.

Required cases:

- real notch width and height from safe-area inputs
- non-notched fallback sizing
- centered anchoring
- external display with no notch
- changed menu bar height fallback

### 2. State-machine tests

Test shell state transitions independently from AppKit.

Required cases:

- closed to peek
- peek auto-dismiss to closed
- closed to open
- open pinned state
- repeated hover events do not create invalid transitions
- reduced-motion mode still preserves state correctness

### 3. Window-configuration tests

Wrap panel creation in a factory so the resulting configuration can be asserted.

Required assertions:

- style mask includes borderless and non-activating behavior
- panel is non-opaque with clear background
- panel does not become key or main by default
- collection behavior includes Spaces and fullscreen support

### 4. Coordinator tests

Test shell coordinator behavior with fake screen data.

Required cases:

- selecting a target screen
- rebuilding geometry after screen changes
- re-anchoring after shell size changes
- keeping one shell instance per targeted display

### 5. UI tests

Add UI tests for the visible behavior that users actually experience.

Required cases:

- app launches with a shell present
- hover enters the shell hot zone and produces the expected state
- open state appears without breaking the shell layout
- shell remains anchored after a resize or state change

These tests should be backed by accessibility identifiers from day one.

### 6. Manual hardware checks

Some shell behavior still requires manual verification on real hardware.

Required manual checks:

- notched MacBook display
- non-notched external display
- fullscreen app coexistence
- Spaces switching
- haptics supported hardware
- haptics unsupported hardware or disabled configuration

## Recommended Phase 0 Implementation Order

1. Create a runnable Xcode macOS app target with unit and UI test targets.
2. Define `ShellPresentationState`, `PeekReason`, and shell configuration models.
3. Implement `ShellGeometryResolver` as pure testable logic.
4. Implement `ShellPanelFactory` and `ShellWindowController`.
5. Implement `ShellCoordinator` for one selected display.
6. Implement `ShellRootView` and closed, peek, and open layout containers.
7. Implement `HapticsService`.
8. Add dedicated geometry, state, coordinator, and window-configuration tests.
9. Add UI tests for launch and state transitions.

## Phase 0 Exit Criteria

Phase 0 should be considered complete when:

- the app launches as a runnable macOS shell target
- the shell is rendered through `NSPanel`
- the shell uses real notch-safe geometry
- closed, peek, and open states are stable
- the shell does not steal focus during standard use
- haptics work where supported and degrade cleanly where unsupported
- dedicated shell tests pass after shell edits

## Sources

Apple:

- `NSScreen.safeAreaInsets`
  - https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
- `NSScreen.auxiliaryTopLeftArea`
  - https://developer.apple.com/documentation/appkit/nsscreen/3882915-auxiliarytopleftarea
- `NSScreen.auxiliaryTopRightArea`
  - https://developer.apple.com/documentation/appkit/nsscreen/3882916-auxiliarytoprightarea
- `NSPanel`
  - https://developer.apple.com/documentation/appkit/nspanel
- `NSWindow.CollectionBehavior.canJoinAllSpaces`
  - https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces
- `NSWindow.CollectionBehavior.fullScreenAuxiliary`
  - https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary
- `NSWindow.StyleMask.nonactivatingPanel`
  - https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- `NSWindow.didChangeScreenNotification`
  - https://developer.apple.com/documentation/appkit/nswindow/didchangescreennotification
- `NSWorkspace.activeSpaceDidChangeNotification`
  - https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification
- `NSHapticFeedbackManager`
  - https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager
- `NSHostingView`
  - https://developer.apple.com/documentation/swiftui/nshostingview
- `Swift Testing`
  - https://developer.apple.com/documentation/testing
- `Defining Test Cases and Test Methods`
  - https://developer.apple.com/documentation/xctest/defining-test-cases-and-test-methods
- `User Interface Testing`
  - https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/09-ui_testing.html

Public reference implementations:

- DynamicNotchKit
  - https://github.com/MrKai77/DynamicNotchKit
- Boring Notch
  - https://github.com/TheBoredTeam/boring.notch
