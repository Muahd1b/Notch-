# Notch- Adapter Architecture

Date: March 9, 2026
Status: Active target architecture

> [!TIP]
> This document defines the system shape. The recommended construction order lives in the [build plan](./build-plan.md). The currently implemented slice is tracked in [current-state](./current-state.md).

## Purpose

This document defines the technical architecture for `Notch-` integrations.

The key requirement is that `Notch-` should feel like one coherent notch surface even though its data comes from many systems with different integration styles:

- local OS frameworks
- local files
- local health checks
- web APIs
- optional event emitters and hooks

## Goals

- keep the shell stable even when adapters fail
- normalize heterogeneous sources into a small set of UI-friendly models
- support both polling and event-driven integrations
- allow low-risk modules to ship before higher-risk ones
- make it easy to add new connectors later

## Non-Goals

- expose raw external schemas directly to UI
- let modules reach into each other’s storage
- require a single transport style for every integration

## System Overview

`Notch-` should be built as four layers:

1. shell layer
2. module domain layer
3. adapter layer
4. persistence and sync layer

## 1. Shell Layer

The shell layer owns:

- overlay windowing
- closed / peek / open state transitions
- animation rhythm
- haptic playback
- module presentation
- closed-state prioritization

The shell layer must not know how Notion, EventKit, or agent logs work.

It should consume only normalized domain models and UI signals.

## 2. Module Domain Layer

Each product area should have a domain module:

- `ScheduleModule`
- `AgentsModule`
- `LocalhostModule`
- `HabitsModule`
- `LearningModule`
- `FocusModule`

Each module owns:

- presentation mapping
- module-local view models
- module-specific rules
- user actions for that domain

Each module consumes domain entities from the event bus or store.

## 3. Adapter Layer

Adapters translate external systems into internal events and entities.

### Adapter categories

#### Framework adapters

Examples:

- EventKit adapter
- AppKit display geometry adapter

#### API adapters

Examples:

- Notion API adapter
- OpenClaw gateway adapter

#### Observer adapters

Examples:

- Codex local observer
- Claude local observer
- filesystem-backed learning imports later

#### Active probe adapters

Examples:

- localhost health checker

#### Event bridge adapters

Examples:

- Claude hooks bridge
- Codex wrapper emitter

## Adapter Contract

Every adapter should conform conceptually to the same contract.

### Required responsibilities

- declare capabilities
- start and stop cleanly
- publish normalized events
- publish connection / health state
- expose last sync timestamp
- expose confidence

### Suggested interface

```swift
protocol NotchAdapter {
    var id: String { get }
    var kind: AdapterKind { get }
    var health: AdapterHealth { get }
    var confidence: AdapterConfidence { get }

    func start() async
    func stop() async
    func refresh() async
}
```

Adapters should write into the event bus and local store, not directly into UI state.

## 4. Persistence and Sync Layer

This layer owns:

- local database or structured store
- sync timestamps
- cached snapshots
- token / credential references
- optimistic local updates

The store should be local-first.

External systems should be treated as:

- source of truth for selected domains
- synchronization targets for selected user actions

## Event Bus

The event bus is the central contract between adapters and modules.

### Responsibilities

- receive domain events from adapters
- fan out updates to modules
- debounce noisy sources
- persist selected events
- trigger peek notifications when rules match

### Event kinds

- `entityUpserted`
- `entityRemoved`
- `signalChanged`
- `adapterHealthChanged`
- `transientEventRaised`

### Example flow

1. Claude observer notices a changed project/session file.
2. Claude adapter emits `AgentEvent`.
3. Event bus normalizes and stores it.
4. Agents module updates the open-state panel.
5. Shell rules decide whether this event should trigger a peek.

## Closed-State Prioritization

The closed notch cannot show everything at once.

A prioritization service should choose which signals are visible.

### Candidate priorities

1. active Pomodoro nearing completion
2. meeting starting soon
3. agent failure or completion
4. localhost outage
5. habits needing completion
6. learning focus reminder

Rules should be:

- user-configurable
- deterministic
- low-noise

## Refresh Strategy

Different connectors need different refresh models.

### Event-driven

- EventKit notifications
- Claude hooks
- OpenClaw gateway events

### File-observer driven

- Codex local observer
- Claude local observer

### Polling

- localhost health checks
- Notion sync

### Timer-driven

- Pomodoro countdown

## Failure Isolation

Each adapter must fail independently.

Rules:

- no adapter crash should break the shell
- adapter failures should surface through health state only
- degraded adapters must keep cached state visible where safe
- the UI must clearly distinguish:
  - disconnected
  - stale
  - unauthorized
  - unsupported

## Permissions and Credentials

Permissions must be separated from adapters.

Recommended service:

- `PermissionsManager`

Responsibilities:

- track OS permission state
- track web integration auth state
- expose “ready / needs setup / denied” per module

Credentials should be stored securely using native macOS secure storage where possible.

## Recommended Internal Services

- `ShellCoordinator`
- `DisplayGeometryService`
- `HapticsService`
- `AdapterRegistry`
- `EventBus`
- `PersistenceStore`
- `PermissionsManager`
- `ClosedStatePriorityService`
- `PeekDecisionService`

## Adapter Registry

The adapter registry should own adapter lifecycle.

Responsibilities:

- register adapters
- start eligible adapters
- stop adapters on shutdown
- restart adapters on configuration changes
- expose aggregate health for diagnostics

This prevents module code from manually instantiating integrations ad hoc.

## Module Boundaries

### `ScheduleModule`

Consumes:

- `CalendarItem`
- `Event`

Sources:

- EventKit adapter

### `AgentsModule`

Consumes:

- `AgentSession`
- `AgentEvent`

Sources:

- Codex observer adapter
- Claude observer adapter
- Claude hooks adapter
- OpenClaw gateway adapter

### `LocalhostModule`

Consumes:

- `LocalService`

Sources:

- localhost probe adapter

### `HabitsModule`

Consumes:

- `HabitEntry`

Sources:

- local habits adapter
- Notion habits adapter

### `LearningModule`

Consumes:

- `LearningEntry`

Sources:

- local learning adapter
- Notion learning adapter

### `FocusModule`

Consumes:

- `FocusSession`

Sources:

- Pomodoro engine

## Recommended V1 Architecture Decisions

- Local-first store
- Modular adapters with shared contracts
- Event bus between adapters and modules
- Polling for Notion and localhost
- Observers for Codex and Claude
- Gateway adapter for OpenClaw
- No deep process inspection in V1

## Recommended V1 File Structure

Suggested internal structure when implementation starts:

```text
Sources/
  Shell/
  Modules/
    Schedule/
    Agents/
    Localhost/
    Habits/
    Learning/
    Focus/
  Adapters/
    EventKit/
    Notion/
    CodexObserver/
    ClaudeObserver/
    ClaudeHooks/
    OpenClawGateway/
    LocalhostProbe/
  Core/
    EventBus/
    Persistence/
    Permissions/
    Haptics/
    Display/
```

## Implementation Order

1. Shell + display geometry + haptics
2. Event bus + store + adapter registry
3. Pomodoro + localhost + calendar
4. Notion habits and learnings
5. Claude observer + Codex observer
6. OpenClaw gateway
7. enhanced event-driven adapters

This sequence is expanded into milestone-level detail in the [build plan](./build-plan.md).

## Architectural Decision

`Notch-` should be built as a shell with adapters, not as a monolith with special-case integrations.

That is the only approach that will let the product scale from:

- one notch shell
- to many personal signals
- without collapsing into unmaintainable feature-specific glue code
