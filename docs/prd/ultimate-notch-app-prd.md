# Notch- Product Requirements Document

Date: March 9, 2026
Status: Draft v1
Product: `Notch-`

## 1. Product Summary

`Notch-` should be the definitive utility surface for the MacBook notch area: a fast, ambient, premium-feeling top-of-screen layer that turns the notch into a useful system canvas instead of a dead hardware constraint.

The product should combine:

- live activity style status surfaces
- utility shortcuts and transient system controls
- drag-and-drop shelf behavior
- media and communication context
- extensible mini-apps and automations

The product should not start as a kitchen sink. It needs a strong core loop, a clear architecture boundary between public and privileged capabilities, and a release plan that keeps V1 shippable.

## 2. Product Vision

Build the best notch-native companion for macOS:

- visually integrated with the camera housing area
- instant and ambient, not a dashboard that users must open deliberately
- high-signal, low-friction, and interaction-light
- customizable without becoming messy
- architected for both safe distribution and more powerful advanced modes

## 3. Problem Statement

MacBook users with notched displays have a prominent top-of-screen hardware constraint with almost no system-level personalization. Existing apps prove the notch can become useful, but the category is fragmented:

- some products are gimmicky
- some are too media-centric
- some rely heavily on brittle private integrations
- few define a clean, extensible platform model

There is room for a product that is:

- genuinely useful every day
- visually refined
- modular
- technically disciplined

## 4. Product Goals

### Primary goals

- Turn the notch into a high-frequency utility surface users interact with multiple times per day.
- Deliver clear value in under five minutes after install.
- Provide a premium baseline using public macOS APIs.
- Support optional advanced capabilities without forcing risky architecture into the core.

### Secondary goals

- Create a foundation for mini-modules and third-party or internal extensions.
- Support multi-display and non-notched display fallbacks gracefully.
- Make the product feel native, stable, and intentional rather than hacky.

## 5. Non-Goals

- Replace the full menu bar.
- Recreate iPhone Dynamic Island literally.
- Ship every possible system integration in V1.
- Depend on private frameworks for core product value.
- Require unsandboxed helpers for the basic experience.

## 6. Target Users

### Core users

- MacBook Pro and MacBook Air users with a notched display
- users who keep many apps open and want faster access to ambient status
- users who value polished desktop utilities

### Secondary users

- creators who want quick media, camera, recording, and drag workflows
- productivity-focused users who want calendar, reminders, timers, and clipboard-adjacent surfaces
- power users interested in automation and configurable system affordances

## 7. Product Principles

- Ambient first: the app should surface state without demanding attention.
- One-second value: important interactions must feel instant.
- Visual restraint: the notch surface must stay dense but calm.
- Progressive power: simple by default, deeper when configured.
- Safe core, powerful edge: public-API-first baseline with optional advanced capability tiers.
- Per-display correctness: geometry and behavior must always respect the active screen.

## 8. Product Strategy

### Recommended strategy

Adopt a dual-track product strategy:

- `Core Mode`
  - public-API-first
  - stable
  - broadly distributable
  - enough value to stand alone
- `Advanced Mode`
  - optional privileged capabilities
  - clearly labeled
  - isolated behind capability checks and separate architecture boundaries

This preserves product credibility and shipping velocity while leaving room for more aggressive system integrations later.

## 9. Core User Jobs

- See and control current media without switching context.
- Drop files into a top-of-screen shelf during multitasking.
- View quick system states like battery, charging, timers, and calendar context.
- Access a compact transient HUD for selected actions.
- Launch or act on lightweight contextual widgets from the notch.

## 10. Core Experience

`Notch-` should have three main interaction layers:

### 1. Closed state

The closed state visually aligns with the notch area and can display subtle live indicators:

- now playing pulse
- battery or charging state
- recording or mic state
- timer progress
- unread or pending state badges

### 2. Peek state

A compact expansion used for:

- media controls
- timer completion
- battery/charging event
- quick file-drop confirmation
- calendar next-up glance

### 3. Open state

A fuller panel for:

- media details and controls
- shelf contents
- quick widgets
- pinned mini-app modules

## 11. Feature Scope

### V1 Must-Have

- notch-aware overlay window system
- single-display support with correct geometry
- optional all-display support
- closed / peek / open states
- drag-to-shelf file intake
- media live activity and transport controls
- battery and charging activity
- calendar next-up widget
- customizable shortcut to open / toggle
- settings UI
- onboarding and permissions flow

### V1.5 Should-Have

- reminders widget
- timers and countdowns
- clipboard recent items
- camera mirror
- per-module enable/disable
- layout presets
- richer animation system

### V2 Could-Have

- extension or plugin system
- automation triggers and actions
- app-specific live activities
- browser download live activities
- communication widgets
- device-connectivity widgets
- advanced HUD replacement
- lock-screen aware behavior

## 12. Differentiation

`Notch-` should differentiate through:

- stronger product architecture than novelty-first notch apps
- a better ambient information model
- cleaner modularity and settings
- less dependence on fragile/private functionality for core value
- a clearer path toward extensibility

## 13. Functional Requirements

### Windowing and layout

- The app must render as a top-centered overlay panel on supported displays.
- The closed state must match real notch geometry when available.
- The app must gracefully fall back on non-notched displays.
- The app must support screen changes, resolution changes, and display attach/detach events.
- The app must support fullscreen-safe behavior where possible.

### State management

- The product must support `closed`, `peek`, and `open` states.
- Each state must be driven by explicit triggers and timeouts.
- Per-display state must be isolated from shared global state where necessary.

### Shelf

- Users must be able to drag supported items into the notch region.
- The shelf must preserve dropped items for a configurable time or until manually removed.
- The shelf must expose clear actions for open, reveal, share, and remove.

### Media

- The product must show current media title, artist, artwork, and playback state.
- The product must support play/pause, next, previous, and open-source-app actions.
- The product should support multiple media backends via a common abstraction.

### Utility widgets

- The product must support battery activity.
- The product must support calendar next-up state.
- The product should support reminders and timers in follow-up milestones.

### Settings

- Users must be able to choose display behavior.
- Users must be able to control which modules are enabled.
- Users must be able to configure shortcuts and appearance preferences.
- Users must see capability-specific permission states and explanations.

## 14. Non-Functional Requirements

- Startup should feel near-instant.
- Closed-state UI should remain visually stable with no obvious jitter.
- The app must avoid stealing focus during normal ambient interactions.
- The product must handle display changes without orphaned or misplaced windows.
- Feature modules must degrade cleanly when permissions are denied.
- The app must remain useful if advanced integrations are disabled.

## 15. Technical Architecture

### Recommended architecture

- SwiftUI for product UI
- AppKit `NSPanel` overlay windows for notch rendering
- one window per target display
- a shared product coordinator plus per-display view models
- feature managers per domain:
  - media
  - battery
  - calendar
  - shelf
  - timers
  - permissions
- capability adapters for integrations with clear boundaries

### Capability tiers

#### Tier 1: Safe / core

- `NSScreen` geometry and safe area math
- AppKit overlay windows
- EventKit
- AVFoundation camera
- drag-and-drop
- user notifications
- settings and shortcuts

#### Tier 2: Sensitive but acceptable with user consent

- Apple Events automation for specific app control
- accessibility-dependent features
- optional background helpers only when clearly justified

#### Tier 3: Advanced / risky

- private frameworks
- lock-screen-specific display behavior
- full HUD replacement
- system brightness or backlight manipulation through private interfaces

Tier 3 must not be required for product-market fit.

## 16. Distribution Strategy

### Recommended

Start with a public-API-first build that can ship broadly and stay maintainable.

Then evaluate one of these paths:

1. keep one binary and gate advanced features behind capability checks
2. ship a stable main app and a separate advanced companion/helper
3. maintain a public-safe release channel and an advanced experimental release channel

## 17. Permissions Model

The product must request permissions progressively.

Rules:

- only request permission at the moment of value
- explain why before prompting
- show degraded fallback when denied
- avoid asking for accessibility, automation, camera, or calendar access at first launch unless the user enters the related feature flow

## 18. UX Requirements

- Closed state must remain elegant and quiet.
- Peek state must resolve in less than a second.
- Open state must avoid feeling like a miniature dashboard stuffed into the notch.
- Motion should reinforce state changes, not decorate them.
- Module switching must feel intentional and stable.
- Users must always understand why the notch opened.

## 19. Success Metrics

### Product metrics

- day-1 activation rate
- percentage of users who enable at least one core module
- daily open or peek interactions per active user
- weekly retention
- shelf usage frequency
- media interaction completion rate

### Quality metrics

- crash-free sessions
- display-reposition correctness after monitor changes
- permission acceptance by feature
- latency from trigger to visible notch response

## 20. Risks

- Over-scoping the product into an unstable utility suite
- depending too early on private or fragile APIs
- poor multi-display behavior
- overlay windows conflicting with fullscreen apps
- permission fatigue from too many feature prompts
- UI becoming cluttered as modules grow

## 21. Open Decisions

- Should V1 include camera mirror, or keep V1 strictly utility-first?
- Should the shelf be transient or persistent by default?
- Should `Notch-` prioritize media as the hero use case, or position itself as a broader ambient operating layer?
- Should Advanced Mode exist in the main binary or as a companion/helper architecture?

## 22. Recommended V1 Definition

The strongest V1 is:

- real notch-aware overlay shell
- clean closed / peek / open state system
- shelf
- media live activity
- battery activity
- calendar next-up
- settings and shortcut model

This is enough to feel like a real product, not a prototype, while keeping the technical foundation disciplined.

## 23. Recommended Next Documents

After this PRD, the next planning artifacts should be:

- system architecture doc
- module model and event bus design
- permissions and capability matrix
- windowing and display-behavior spec
- V1 implementation plan

## 24. Product Thesis

If Boring Notch proved the notch can be playful, `Notch-` should prove the notch can become a serious ambient interface layer for macOS.
