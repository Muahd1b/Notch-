# Notch- Product Requirements Document

Date: March 9, 2026
Status: Draft v2
Product: `Notch-`

> [!TIP]
> The recommended implementation sequence for this PRD is documented in the [build plan](../architecture/build-plan.md).

## 1. Product Summary

`Notch-` is a personal operating layer for the MacBook notch.

It should reproduce the interaction quality of Boring Notch:

- notch-matched closed state
- fluid hover expansion
- tactile confirmations and micro-feedback
- premium motion rhythm
- top-centered, always-ambient behavior

But its information architecture should be different. Instead of centering media and novelty, `Notch-` should become a personal monitoring system for development work and daily habits.

The product should surface:

- Apple Calendar context
- current Codex, OpenClaw, and Claude Code activity
- running localhost services
- habits and habit streaks
- current learnings
- Pomodoro / focus tracking

## 2. Product Vision

Build the best notch-native command center for a solo builder:

- visually and behaviorally on par with Boring Notch
- focused on actual daily workflow rather than generic widgets
- ambient in the closed state, rich in the open state
- opinionated around developer operations, habits, and focus
- extensible through adapters and module connectors

## 3. Design Direction

### Core design requirement

The product should target interaction parity with Boring Notch.

That means:

- the notch should visually feel attached to the hardware cutout
- hover and expansion timing should feel similarly crisp and responsive
- drag interactions should feel magnetic and deliberate
- subtle haptics should confirm meaningful transitions
- the UI should remain dark, clean, dense, and premium

### Important constraint

The goal is interaction parity, not literal asset cloning.

`Notch-` should not depend on Boring Notch branding, artwork, copy, or exact feature framing. It should define its own module layout, content hierarchy, and product identity around monitoring and personal systems.

## 4. Problem Statement

Your day is split across multiple disconnected systems:

- Apple Calendar for schedule and commitments
- Codex, Claude Code, and OpenClaw for active AI-assisted work
- local dev servers for what is currently live
- Notion for habits and personal tracking
- ad hoc notes and fragments for current learning
- separate timer apps for focus sessions

None of those systems share a single ambient, high-frequency surface. The menu bar is too small, dashboards are too deliberate, and context is scattered.

The notch is uniquely suited to become that surface because it is:

- always visible
- close to the top of visual attention
- naturally compact in the resting state
- expandable when deeper context is needed

## 5. Product Goal

Turn the notch into the primary glanceable surface for your workday state.

Success means:

- you can tell what matters in under one second
- the notch gives you a live sense of schedule, focus, and active work
- you can open a richer context panel without leaving your current task
- the product becomes part of daily behavior, not a toy

## 6. Non-Goals

- Replace your full project management stack.
- Be a general-purpose widget launcher for every app on the system.
- Depend on private frameworks for the baseline experience.
- Require deep setup before the product becomes useful.
- Be visually generic or dashboard-like.

## 7. Target User

Primary user:

- a solo technical operator or founder
- heavy Mac user
- runs multiple AI coding agents
- juggles project work, habits, and learning
- wants ambient visibility, not another heavyweight dashboard

Secondary future users:

- developers running multiple local environments
- agency operators or PMs supervising agents and schedules
- power users who want a structured “operating layer” above the desktop

## 8. Core Product Thesis

`Notch-` should answer one question continuously:

What is happening in my day and in my work right now?

That answer should be encoded into a compact, living notch surface that expands into detail only when needed.

## 9. Core Product Areas

### 1. Schedule

Show upcoming events, current meeting windows, and the next relevant time block from Apple Calendar.

### 2. Agent Activity

Show what Codex, Claude Code, and OpenClaw are doing now:

- active vs idle
- current workspace or session
- latest event or task
- health / blocked state where available

### 3. Local Development State

Show which local hosts are running and whether important local services are healthy.

### 4. Habits

Show today’s habits, completion status, streaks, and the next small action.

### 5. Learning

Show what is currently being learned, tracked, or reviewed.

### 6. Focus

Show Pomodoro timer state, focus status, and optionally time-tracking summaries.

## 10. Experience Model

`Notch-` should have four experience layers.

### Closed State

The closed notch is the constant glanceable surface.

It should show a compressed summary such as:

- current focus state
- next calendar event countdown
- count of active agents
- localhost health indicator
- habit completion progress

It should remain quiet unless a meaningful change occurs.

### Peek State

Peek is a short expansion for transient events:

- meeting starts soon
- agent completed or failed
- localhost went down or came up
- Pomodoro ended
- habit check-in prompt

Peek should auto-dismiss unless pinned open by the user.

### Open State

Open is the richer dashboard panel anchored to the notch.

It should contain module panes for:

- calendar
- agents
- localhost
- habits
- learnings
- focus

### Action State

Action state is a temporary deeper interaction area for:

- marking a habit complete
- starting or pausing a Pomodoro
- opening an agent session
- opening a localhost service
- capturing a learning entry

## 11. Interaction Requirements

- Hovering the notch should feel intentional and premium.
- Expansion should not steal focus.
- Transitions should feel physically attached to the hardware notch.
- Important transitions should use macOS haptic feedback where supported.
- Dragging files or URLs into the notch should be supported if the shelf remains part of the product.
- The product must feel alive without being noisy.

## 12. Haptics Requirements

The product should implement tactile confirmations similar in spirit to Boring Notch:

- open / snap confirmation
- successful drop interaction
- important state resolution
- optional completion feedback for timers and habits

Requirements:

- use platform-supported macOS haptics where available
- make haptics configurable per interaction class
- never make haptics mandatory for product clarity
- gracefully degrade on hardware without supported haptic behavior

## 13. Feature Scope

### V1 Must-Have

- notch-aware overlay shell
- closed / peek / open interaction model
- Boring Notch-style motion and haptic baseline
- Apple Calendar integration
- Codex monitoring
- Claude Code monitoring
- OpenClaw monitoring
- localhost monitoring
- habits module
- Notion sync for habits
- learning log module
- Pomodoro module
- settings UI
- onboarding and permission flows

### V1.5 Should-Have

- shelf for dropped files and links
- richer agent drill-down
- calendar write actions
- habit reminders and nudges
- learning capture shortcuts
- time-tracking summaries
- daily review mode

### V2 Could-Have

- extension system
- cross-device sync
- team monitoring mode
- deeper AI agent orchestration controls
- historical analytics
- weekly review and trend views

## 14. Functional Requirements

### Windowing and rendering

- The app must render as a top-centered overlay panel.
- The closed state must match the real notch geometry when available.
- The app must work on non-notched displays with a graceful fallback.
- The app must support multiple displays.
- The app must survive display changes without visible breakage.

### Calendar

- The app must show the current or next Apple Calendar event.
- The app must support multiple calendars.
- The app should support simple filtering by selected calendars.

### Agent monitoring

- The app must expose one normalized “agent activity” model across Codex, Claude Code, and OpenClaw.
- The app must distinguish:
  - active
  - idle
  - completed
  - blocked / error
- The app should display workspace/session identity when available.
- The app must support adapters with different data quality levels per tool.

### Localhost monitoring

- The app must track configured local hosts and health endpoints.
- The app must show whether a service is up, down, or degraded.
- The app should support opening a service directly in the browser.

### Habits

- The app must show today’s habits and completion status.
- The app must support local-first habit tracking even if Notion is disconnected.
- The app should sync with a Notion-backed habits source of truth.

### Learning

- The app must support lightweight learning entries.
- The app should allow a “current learning focus” object, not just an unstructured note feed.
- The app should support Notion as the primary external sync target.

### Pomodoro and focus

- The app must provide a first-party Pomodoro timer.
- The app must support start, pause, resume, skip, and complete.
- The app should support writing focus summaries into history.
- The app may optionally sync focus blocks into Notion or Calendar later.

## 15. Product Architecture

### Recommended architecture

- runnable macOS app target first for initial delivery
- SwiftUI for UI
- AppKit `NSPanel` windows for notch rendering
- one window per display
- one shared coordinator plus per-display view models
- adapter-based module system

Core modules:

- `schedule`
- `agents`
- `localhost`
- `habits`
- `learning`
- `focus`

Core shared services:

- permissions manager
- animation / interaction engine
- haptics service
- sync scheduler
- local store
- event bus

## 16. Integration Architecture

Each external system should be connected through an adapter with a normalized output model.

### Adapter contract

Each adapter should define:

- capability level
- auth or permission model
- freshness model
- observable entities
- failure modes
- privacy impact

### Capability tiers

#### Tier A: Official and stable

- Apple Calendar via EventKit
- Notion via Notion API
- OpenClaw via documented gateway/session model if available in deployment

#### Tier B: Local observation / semi-stable

- Codex via local session files and optional wrappers
- Claude Code via local project/session state and optional hooks
- localhost via configured probes and process-adjacent observation

#### Tier C: Optional advanced

- deeper process inspection
- privileged socket / process mapping
- private framework use

The baseline product must ship with Tier A and Tier B. Tier C is optional and must not block V1.

## 17. Data Model

The product should normalize all sources into a small set of primitives:

- `Signal`
  - a small, glanceable state visible in the closed notch
- `Event`
  - a time-based change such as a meeting, timer finish, or agent completion
- `ModuleCard`
  - a richer open-state representation of one domain
- `Action`
  - an executable control such as start timer, open host, mark habit done

Domain-specific entities:

- `CalendarItem`
- `AgentSession`
- `LocalService`
- `HabitEntry`
- `LearningEntry`
- `FocusSession`

## 18. Settings Model

Users must be able to configure:

- module visibility and order
- closed-state priority rules
- haptic intensity / enabled events
- hover behavior
- auto-open rules
- display targeting
- calendar source selection
- Notion workspace / data source mapping
- localhost service registry

## 19. Privacy and Security

- The product must default to local-first storage for sensitive state.
- External sync should be opt-in.
- Agent telemetry should never be sent externally by default.
- Tokens for Notion or other services must be stored securely.
- Monitoring should stay read-oriented unless the user enables write actions.

## 20. Orchestration and Validation

The build process for `Notch-` should be orchestration-driven, not edit-only.

The first delivery vehicle should be a runnable macOS app target so shell behavior can be verified on real hardware before the architecture is extracted into reusable packages.

After any code-editing task completes, the system should run dedicated tests for the subsystem that was changed before the work is considered complete.

Requirements:

- shell and interaction changes must be followed by dedicated shell, state, or UI behavior tests
- adapter and integration changes must be followed by dedicated adapter or integration tests
- store, event bus, and coordinator changes must be followed by dedicated infrastructure tests
- phase-level work should end with a targeted validation pass, not only a generic full-suite run
- manual visual checks are useful, but they do not replace dedicated automated tests
- every new module should define its expected validation surface as part of implementation

The testing model should stay aligned with the phased build plan:

- Phase 0 should validate shell behavior, geometry, animation, focus safety, and haptics
- Phase 1 should validate the event bus, adapter lifecycle, module registration, and store behavior
- later phases should validate each module and adapter with tests specific to their domain

## 21. Risks

- “Boring Notch parity” can drift into imitation instead of product identity.
- Codex and Claude Code may not expose clean status APIs.
- localhost monitoring can become messy if it relies on deep process introspection.
- Notion can become a bottleneck if habits and learning models are over-designed.
- too many simultaneous modules can overload the notch surface

## 22. Recommended V1

V1 should ship as:

- Boring Notch-grade shell and interaction quality
- calendar module
- agents module
- localhost module
- habits module
- learning module
- Pomodoro module

The core closed state should summarize:

- next event
- active agent count
- host health count
- habit progress
- current focus timer

## 23. Open Questions

- Do you want the shelf to remain in V1, or should the product be purely monitoring-first?
- Should “current learnings” be sourced only from Notion in V1, or also from local markdown notes?
- Should the localhost module prioritize manually registered hosts or automatic detection?
- Do you want write-back actions in V1, or should V1 stay mostly read-first?

## 24. Next Documents

- integration research and feasibility matrix
- system architecture doc
- module event model
- closed-state prioritization spec
- build plan
