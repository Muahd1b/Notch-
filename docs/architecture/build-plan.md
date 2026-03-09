# Notch- Build Plan

Date: March 9, 2026
Status: Draft

## Purpose

This document defines the recommended starting sequence for building `Notch-`.

The key principle is:

- do not build all integrations at once
- build the shell first
- optimize the first milestone for a runnable macOS app
- validate the notch surface with a few high-value modules
- add ambiguous agent integrations only after the product already works

## Build Strategy

`Notch-` should be built in four stages:

1. shell foundation
2. core app spine
3. guaranteed-value modules
4. advanced adapters

This keeps risk low while making the notch experience testable very early.

For Phase 0, the fastest correct path is a runnable Xcode macOS app target, not a package-first extraction.

## Validation Rule

After any code-editing task, run dedicated tests for the subsystem that changed.

This project should not treat validation as a single generic step at the very end.

Examples:

- shell changes: shell geometry, state, interaction, and UI behavior tests
- infrastructure changes: store, event bus, coordinator, and adapter lifecycle tests
- module changes: dedicated tests for the touched module or adapter

Manual visual checks should complement this, but not replace it.

## Phase 0: Shell Foundation

> [!TIP]
> Implementation research for this phase lives in [Phase 0 shell research](../research/phase-0-shell-research.md).

Build the notch shell before any external integrations.

### Goals

- prove the notch can function as a daily-use surface
- lock in the visual and interaction quality
- validate windowing, animation, and haptics

### Scope

- Xcode macOS app scaffold
- app target, unit test target, and UI test target
- `NSPanel` overlay shell
- real notch geometry via `NSScreen`
- closed / peek / open states
- hover behavior
- animation timing and transition rules
- haptics service
- closed-state layout skeleton
- open-state panel container

### Exit Criteria

- app launches as a runnable macOS shell
- notch renders correctly on the target display
- transitions feel premium and stable
- haptic feedback works where supported
- shell does not steal focus during normal interactions
- dedicated shell and interaction tests pass after shell edits

## Phase 1: Core App Spine

Once the shell works, build the infrastructure that all modules will depend on.

### Scope

- local persistence layer
- event bus
- adapter registry
- module registry
- settings model
- permissions manager
- closed-state prioritization service
- basic diagnostics surface for adapters

### Exit Criteria

- modules can register independently
- shell can consume normalized data from the store
- adapters can start, stop, and publish health cleanly
- dedicated infrastructure tests pass after core-spine edits

## Phase 2: Guaranteed-Value Modules

Build the integrations that are the easiest and most reliable first.

### Recommended modules

- Pomodoro
- Apple Calendar
- localhost health checks

### Why these first

- they create daily value immediately
- they are technically clear
- they validate the closed-state information density
- they do not depend on reverse-engineering agent behavior

### Scope

#### Pomodoro

- local timer engine
- start / pause / resume / complete
- completion peek
- optional haptic completion

#### Apple Calendar

- next event
- current event
- countdown
- selected calendar filtering

#### Localhost

- user-defined service registry
- health probe polling
- open-in-browser actions
- degraded / recovered event peeks

### Exit Criteria

- the closed notch can summarize:
  - next event
  - focus timer
  - localhost health
- the open state can show useful detail for all three modules
- dedicated module tests pass for Pomodoro, Calendar, and localhost work

## Phase 3: Personal Tracking Modules

After the shell proves useful, layer in personal systems.

### Recommended modules

- local habits model
- local learning model
- Notion sync for both

### Scope

- local-first habits storage
- local-first learning entries
- Notion connector
- sync state and conflict handling

### Exit Criteria

- habits and learnings work without network dependency
- Notion is additive, not mandatory
- dedicated module and sync tests pass after habits, learning, and Notion changes

## Phase 4: Agent Monitoring

Only after the product already works as a daily operating layer should agent monitoring be added.

### Recommended order

1. Claude Code local observer
2. Codex local observer
3. OpenClaw gateway adapter
4. Claude hooks adapter
5. Codex wrapper emitter

### Why agent monitoring is later

- agent systems have uneven observability
- they are the most likely to drift or break
- they should plug into an already-validated shell

### Exit Criteria

- agent sessions can be displayed with confidence values
- failures degrade cleanly
- shell remains stable if adapters disconnect
- dedicated adapter tests pass for each agent integration change

## Best First Milestone

The best initial milestone is not “all integrations.”

It is:

- working notch shell
- one closed-state summary row
- one open-state panel
- Pomodoro
- Calendar next event
- 2 to 3 configured localhost services

This is the smallest version that proves:

- the notch interaction model
- information density
- motion quality
- haptic quality
- actual daily usefulness

## What Not To Do First

- do not start with Codex, Claude Code, and OpenClaw together
- do not start with deep process inspection
- do not start with Notion as the only source of truth
- do not start by building every module pane in detail

## First Implementation Checklist

### Build first

- runnable macOS app target
- unit test target
- UI test target
- shell window
- shell view model
- animation / haptics service
- event bus
- Pomodoro engine
- Calendar adapter
- localhost probe adapter

### Validate second

- closed-state prioritization
- peek triggers
- open-state composition
- display changes
- reduced-noise behavior
- dedicated tests for the subsystem edited in the milestone

### Add later

- habits
- learnings
- Notion sync
- agent adapters

## Dependencies

This plan depends on:

- [Ultimate Notch app PRD](../prd/ultimate-notch-app-prd.md)
- [Integration research](../research/integration-research.md)
- [Integration matrix](../research/integration-matrix.md)
- [Adapter architecture](./adapter-architecture.md)

## Decision

The best way to start building `Notch-` is:

1. shell
2. core infrastructure
3. Pomodoro + Calendar + localhost
4. habits + learnings + Notion
5. agent monitoring
