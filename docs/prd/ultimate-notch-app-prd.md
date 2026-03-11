# Notch- Product Requirements Document

Date: March 11, 2026
Status: Active
Product: `Notch-`

> [!TIP]
> The recommended implementation sequence for this PRD is documented in the [build plan](../architecture/build-plan.md). The current repo state is tracked in [current-state](../architecture/current-state.md).

## 1. Product Summary

`Notch-` is a personal operating layer for the MacBook notch.

It should reproduce the interaction quality of Boring Notch:

- notch-matched closed state
- fluid hover expansion
- tactile confirmations and micro-feedback
- premium motion rhythm
- top-centered, always-ambient behavior

But its information architecture should be different. `Notch-` should become the ultimate personal control and monitoring center for development work and daily operations.

The product should surface:

- home-level summary intelligence across all notch pages
- cross-app notifications from WhatsApp, Discord, Instagram, and Telegram
- Apple Calendar context and fast event/reminder creation
- media controls with queue/recent playback and provider integration
- habits from Notion with progress metrics
- current agent activity from Codex, Claude Code, Ollama, and OpenCode
- HUD and camera utility controls
- localhost service health and RAM usage visibility
- OpenClaw chat and runtime metrics
- multi-business financial performance summaries and charts

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
- page surfaces should use Apple-native macOS UI elements wherever practical

### Important constraint

The goal is exact shell-level UI, haptics, and settings-system parity using the upstream Boring Notch implementation as the primary reference.

`Notch-` should fetch and adapt the actual Boring Notch source for these shell and settings surfaces, while replacing only the content and settings categories that are specific to `Notch-` integrations.

## 4. Problem Statement

Your day is split across multiple disconnected systems:

- Apple Calendar for schedule and commitments
- Codex, Claude Code, Ollama, OpenCode, and OpenClaw for active AI-assisted work
- WhatsApp, Discord, Instagram, and Telegram for communication signals
- local dev servers for what is currently live
- Spotify and Apple Music for media context
- Notion for habits and personal tracking
- business systems for financial visibility
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

### 1. Home

Show summarized overviews from all major modules using compact numbers and icons.

### 2. Notifications

Show incoming notifications from:

- WhatsApp
- Discord
- Instagram
- Telegram

### 3. Calendar

Show Apple Calendar context with a split layout:

- right side: calendar timeline / events list (Boring Notch-style baseline)
- left side: quick-create event and reminder actions

### 4. Media Control

Show media controls with a split layout:

- left side: transport controls in the Boring Notch interaction style
- right side: queue and recently played selection

Supported providers should include Spotify and Apple Music.

### 5. Habits

Show Notion-backed habits with a split layout:

- left side: full habits list
- right side: completion and progress metrics

### 6. Agents Status

Show running agent sessions from Codex, Claude Code, Ollama, and OpenCode.

For each agent, show:

- status: `ongoing` or `idle`
- current process / task summary
- token usage
- token limit

### 7. HUD

Show camera/HUD functionality with Boring Notch-grade interaction behavior, plus practical controls including a window that can show a currently streamed display.

### 8. Localhost

Show all configured/running localhost services, service health, and RAM usage.

### 9. OpenClaw

Show an OpenClaw split layout:

- left side: chat
- right side: metrics such as running time, usage, and MCP status

### 10. Financial Board

Show connected businesses with:

- profit
- MRR
- revenue
- chart-based trend visualization

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

It should contain page panes routed from the top symbol bar in this order:

- home
- notifications
- calendar
- media control
- habits
- agents
- openclaw
- HUD
- localhost
- financial board

The symbol bar layout should group pages by side:

- left side of the notch: home, notifications, calendar, media control, habits, agents, openclaw
- right side of the notch: HUD, localhost, financial board

Page layout requirements in open state:

- home: summarized KPIs and icons from other pages
- notifications: feed grouped by source app and recency
- calendar: right-side calendar view, left-side create/reminder tools
- media control: left-side control surface, right-side queue/recently played
- habits: left-side habit list, right-side progress metrics
- agents: agent rows with `ongoing` / `idle`, process summary, token usage, and limits
- HUD: camera/HUD panel and stream utility controls
- localhost: service list, health, and RAM usage
- openclaw: chat left, metrics right
- financial board: per-business KPIs and chart views

### Action State

Action state is a temporary deeper interaction area for:

- marking a habit complete
- starting or pausing a Pomodoro
- opening an agent session
- acknowledging or dismissing a notification
- opening a localhost service
- controlling media playback and selecting queue items
- creating calendar events and reminders
- sending OpenClaw chat prompts
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
- Apple-style native macOS UI controls across all pages
- home summary page
- notifications page for WhatsApp, Discord, Instagram, Telegram sources
- Apple Calendar integration
- calendar split layout with event/reminder creation tools
- media control page with Spotify and Apple Music integration
- Codex monitoring
- Claude Code monitoring
- Ollama monitoring
- OpenCode monitoring
- OpenClaw monitoring
- OpenClaw chat + metrics page
- localhost monitoring
- localhost RAM usage visibility
- habits module
- Notion sync for habits
- learning log module
- HUD page with camera and stream utility controls
- financial board page with connected business KPIs and charts
- Pomodoro module
- settings window
- settings access from the notch header symbol bar
- top symbol-bar page routing for home, notifications, calendar, media control, habits, agents, openclaw, HUD, localhost, and financial board
- onboarding and permission flows

### V1.5 Should-Have

- shelf for dropped files and links
- richer agent drill-down
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
- The open shell must expose a header symbol bar that can launch settings directly.
- The open shell must expose page symbols in the top bar with a stable order and left/right grouping.
- The shell header, shape language, and settings access pattern should be implemented from the upstream Boring Notch source map.

### Shell interaction language

- The shell should use a small, consistent shape system for the outer notch, symbol-bar controls, and expanded action surfaces.
- The shell should feel visually anchored to the hardware notch.
- Motion and haptics should be implemented from the upstream Boring Notch shell behavior, not merely approximated.
- The same shell interaction language should stay consistent across closed, peek, and open states.
- The app must survive display changes without visible breakage.

### Calendar

- The app must show the current or next Apple Calendar event.
- The app must support multiple calendars.
- The app should support simple filtering by selected calendars.
- The calendar page must present a split layout:
  - right: event timeline/list
  - left: quick-create event/reminder surface

### Home

- The home page must summarize the state of other pages using compact KPIs, numbers, and icons.
- Home cards should prioritize glanceability over verbose text.

### Notifications

- The notifications page must aggregate notifications from WhatsApp, Discord, Instagram, and Telegram.
- Notifications should be grouped by source and ordered by recency.
- The page should support fast clear/acknowledge actions where system permissions allow it.

### Media control

- The media page must include transport controls (play/pause/skip/seek).
- The media page must include a queue and recently played list.
- The app should support Spotify and Apple Music provider integration.

### Agent monitoring

- The app must expose one normalized “agent activity” model across Codex, Claude Code, Ollama, and OpenCode.
- The app must distinguish status:
  - `ongoing`
  - `idle`
- The app should display workspace/session identity when available.
- The app should display process/task summary, token usage, and token limit for each running agent where available.
- The app must support adapters with different data quality levels per tool.

### Localhost monitoring

- The app must track configured local hosts and health endpoints.
- The app must show whether a service is up, down, or degraded.
- The app must show RAM usage per service where available.
- The app should support opening a service directly in the browser.

### HUD

- The HUD page must include camera display behavior aligned with the Boring Notch reference.
- The HUD page should expose useful controls including a stream-display utility window.

### OpenClaw

- The OpenClaw page must support left-side chat interaction.
- The OpenClaw page must support right-side runtime metrics including running time, usage, and MCP status.

### Financial board

- The financial page must support multiple connected businesses.
- The financial page must show per-business profit, MRR, and revenue.
- The financial page must provide chart-based trend views.

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

### Page Implementation Analysis And Needs

This section defines the implementation intent for each page as an execution contract.

#### 1. Home

- Core functions: summarize all page states into compact KPI cards with icon-first hierarchy.
- Needs: closed-state prioritization service, module summary contracts, freshness timestamps, severity scoring for surfacing urgent signals.
- Dependencies: event bus, local store, module registries for calendar/agents/localhost/habits/media/notifications/financial/openclaw.
- Fallback: hide missing module cards and display only healthy summaries.
- Validation: snapshot tests for card composition, ranking tests for priority ordering, UI test for live updates without layout jitter.

#### 2. Notifications

- Core functions: aggregate and render source-aware notifications (WhatsApp, Discord, Instagram, Telegram), support acknowledge/dismiss actions.
- Needs: notification ingestion adapter layer, source normalization (`NotificationItem`), recency ordering, unread counters, deduplication.
- Dependencies: macOS notification observation permissions, optional source app adapters for deep metadata.
- Fallback: when source-level parsing is unavailable, show generic app-level notifications with reduced metadata.
- Validation: adapter mapping tests by source, deduplication tests, UI tests for sorting and unread count behavior.

#### 3. Calendar

- Core functions: right-side schedule view, left-side quick-create event/reminder tools.
- Needs: EventKit read/write adapter, selected calendar filtering, reminder write flow, timezone-safe event rendering.
- Dependencies: calendar/reminders permission, event refresh observers, local cache for instant rendering.
- Fallback: read-only mode when write permission is denied; empty-state guidance when permission is not granted.
- Validation: EventKit adapter tests, creation flow tests, UI tests for split-layout behavior and next-event consistency.

#### 4. Media Control

- Core functions: transport controls (play/pause/skip/seek), right-side queue and recently played selection.
- Needs: provider abstraction for Spotify and Apple Music, playback state service, queue model (`MediaItem`), device context handling.
- Dependencies: provider auth/token management, now-playing observation, playback command bridge.
- Fallback: local now-playing-only mode when provider auth is missing; disable unsupported controls per provider.
- Validation: provider adapter contract tests, playback command tests, UI tests for queue updates and provider switching.

#### 5. Habits

- Core functions: left-side habits list from Notion-backed data, right-side progress metrics and streak summaries.
- Needs: local-first `HabitEntry` store, Notion sync adapter, completion mutation pipeline, streak calculation.
- Dependencies: Notion auth, sync scheduler, conflict-resolution strategy for offline edits.
- Fallback: local-only habit mode when Notion sync is unavailable.
- Validation: streak/completion unit tests, sync conflict tests, UI tests for completion and metric refresh.

#### 6. Agents Status

- Core functions: show active agents with status (`ongoing`/`idle`), process summary, token usage, token limit.
- Needs: provider adapters for Codex, Claude Code, Ollama, OpenCode; normalized `AgentSession` and `AgentUsageSnapshot`; status mapping rules.
- Dependencies: local observer adapters, optional provider APIs, confidence scoring for token/process metrics.
- Fallback: status-only view when usage/limits are unavailable; explicit low-confidence labels for inferred metrics.
- Validation: provider mapping tests, status transition tests, usage aggregation tests, UI tests for multi-provider lists.

#### 7. HUD

- Core functions: camera/HUD presentation and stream-display utility controls.
- Needs: camera session service, stream preview window management, HUD control model (`HUDState`), performance-safe rendering pipeline.
- Dependencies: camera/screen capture permissions, low-latency compositing path, failure-safe fallback surfaces.
- Fallback: display control-only HUD when camera permission is denied or stream source is unavailable.
- Validation: permission-state tests, frame lifecycle tests, manual hardware verification for latency and stability.

#### 8. Localhost

- Core functions: list localhost services, health, and RAM usage.
- Needs: service registry, health probe scheduler, process metrics adapter for RAM, service-event model (`LocalService`).
- Dependencies: polling service, process/port mapping service, configurable probe intervals and debounce.
- Fallback: health-only mode when process-to-service RAM attribution is uncertain.
- Validation: probe success/failure tests, RAM mapping confidence tests, UI tests for degraded/recovered transitions.

#### 9. OpenClaw

- Core functions: left-side chat panel, right-side runtime/usage/MCP metrics.
- Needs: gateway chat adapter, session/runtime telemetry adapter, `OpenClawSession` model, reconnect and retry policy.
- Dependencies: OpenClaw endpoint configuration, auth/token support where required, websocket/push transport.
- Fallback: metrics-only mode when chat transport is unavailable, connection-status banners with retry actions.
- Validation: chat transport tests, reconnect tests, metrics parser tests, UI tests for split-panel sync.

#### 10. Financial Board

- Core functions: connected-business KPI views for profit, MRR, revenue, and trend charts.
- Needs: business connector abstraction, `BusinessMetricsSnapshot` model, chart aggregation pipeline, period and currency normalization.
- Dependencies: connector auth and ingestion scheduling, data quality checks, reconciliation rules across sources.
- Fallback: manual-entry/CSV mode when live connectors are not configured.
- Validation: KPI calculation tests, period rollup tests, chart rendering tests, connector ingestion contract tests.

#### Cross-Page Platform Needs

- Core services: event bus, local persistence, adapter registry, permissions manager, diagnostics service.
- UX guarantees: Apple-native controls, notch-first interaction quality, reduced-motion compliance, low-noise closed-state behavior.
- Reliability rules: no page adapter can block shell rendering; every page must expose degraded mode states.

## 15. Product Architecture

### Recommended architecture

- runnable macOS app target first for initial delivery
- SwiftUI for UI
- AppKit `NSPanel` windows for notch rendering
- one window per display
- one shared coordinator plus per-display view models
- adapter-based module system

Core modules:

- `home`
- `notifications`
- `schedule`
- `media`
- `agents`
- `hud`
- `localhost`
- `habits`
- `learning`
- `focus`
- `openclaw`
- `financial`

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
- Apple Music via official platform APIs
- OpenClaw via documented gateway/session model if available in deployment

#### Tier B: Local observation / semi-stable

- Codex via local session files and optional wrappers
- Claude Code via local project/session state and optional hooks
- Ollama via local runtime APIs / process observation
- OpenCode via local session/state observation
- localhost via configured probes and process-adjacent observation
- WhatsApp / Discord / Instagram / Telegram notification aggregation via macOS notification surfaces and app-local availability
- Spotify via Web API and local app state bridges

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

- `NotificationItem`
- `CalendarItem`
- `MediaItem`
- `AgentSession`
- `AgentUsageSnapshot`
- `HUDState`
- `LocalService`
- `HabitEntry`
- `LearningEntry`
- `FocusSession`
- `OpenClawSession`
- `BusinessMetricsSnapshot`

## 18. Settings Model

Users must be able to configure:

- module visibility and order
- closed-state priority rules
- haptic intensity / enabled events
- hover behavior
- auto-open rules
- display targeting
- calendar source selection
- notification source toggles and source-specific filtering
- media provider setup and auth
- agent provider toggles (Codex, Claude Code, Ollama, OpenCode)
- OpenClaw endpoint and behavior settings
- Notion workspace / data source mapping
- localhost service registry
- financial connector and business mapping setup
- whether the settings gear appears in the notch header symbol bar

The configuration system should be exposed through a full settings window, not through an inline notch-only settings surface.

Settings access requirements:

- the full settings window must be launchable from the notch header symbol bar
- the app may also expose settings from the menu bar or additional shell menus
- shell-facing settings should update live without requiring relaunch where practical
- the structure, access pattern, and control vocabulary should be ported from the upstream Boring Notch settings implementation and adapted to `Notch-` integrations

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

- Phase 0 should validate shell behavior, geometry, animation, focus safety, haptics, and symbol-bar settings access
- Phase 1 should validate the event bus, adapter lifecycle, module registration, store behavior, and settings propagation
- later phases should validate each module and adapter with tests specific to their domain

## 21. Risks

- “Boring Notch parity” can drift into imitation instead of product identity.
- Codex, Claude Code, Ollama, and OpenCode may not expose consistent process/token metrics.
- cross-app notification ingestion may vary by source app behavior and OS permission boundaries.
- localhost monitoring can become messy if it relies on deep process introspection.
- Spotify and Apple Music integration can diverge in capabilities and auth constraints.
- Notion can become a bottleneck if habits and learning models are over-designed.
- financial connectors can introduce data quality and reconciliation complexity.
- too many simultaneous modules can overload the notch surface

## 22. Recommended V1

V1 should ship as:

- Boring Notch-grade shell and interaction quality
- regular macOS settings window with symbol-bar access from the notch shell
- home summary page
- notifications page
- calendar module
- media control module
- agents module
- HUD module
- localhost module
- habits module
- learning module
- OpenClaw page with chat and metrics
- financial board module
- Pomodoro module

The core closed state should summarize:

- next event
- ongoing vs idle agent count
- host health count
- habit progress
- current focus timer
- high-priority notification count

## 23. Open Questions

- Do you want the shelf to remain in V1, or should the product be purely monitoring-first?
- Should “current learnings” be sourced only from Notion in V1, or also from local markdown notes?
- Should social notification support start as macOS-notification aggregation only, or include deeper provider APIs where possible?
- Which financial connectors should be first-party in V1 (manual input, CSV import, accounting APIs, payment APIs)?
- Do you want write-back actions in V1, or should V1 stay mostly read-first?

## 24. Next Documents

- [Docs index](../README.md)
- [Current implementation state](../architecture/current-state.md)
- [Build plan](../architecture/build-plan.md)
- [Adapter architecture](../architecture/adapter-architecture.md)
- [Integration research](../research/integration-research.md)
- [Integration matrix](../research/integration-matrix.md)
- [Phase 0 shell research](../research/phase-0-shell-research.md)
- [Boring Notch source map](../reference/boring-notch-source-map.md)
