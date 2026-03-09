# Notch- Repository Instructions

## Purpose

This repository is for building `Notch-`: a notch-native macOS command center focused on developer workflow and daily-life monitoring.

The product direction is:

- Boring Notch-grade interaction quality
- personal monitoring instead of generic novelty widgets
- modular adapters for external systems
- local-first architecture

## Source Of Truth

Before making changes, read the relevant project docs:

- product requirements:
  - `docs/prd/ultimate-notch-app-prd.md`
- integration feasibility:
  - `docs/research/integration-research.md`
- implementation sequencing:
  - `docs/research/integration-matrix.md`
- adapter system design:
  - `docs/architecture/adapter-architecture.md`
- phased construction order:
  - `docs/architecture/build-plan.md`

If code or implementation ideas conflict with these documents, update the docs first or explicitly document the reason for divergence.

## Product Boundaries

`Notch-` should focus on:

- Apple Calendar
- Codex monitoring
- Claude Code monitoring
- OpenClaw monitoring
- localhost monitoring
- habits
- Notion sync
- learning tracking
- Pomodoro / focus tracking

Avoid expanding into a generic widget shelf for unrelated app ideas unless the scope is intentionally updated in the PRD.

## Build Order

Do not start with every integration at once.

Preferred order:

1. shell foundation
2. core app spine
3. Pomodoro + Calendar + localhost
4. habits + learnings + Notion
5. agent monitoring

The shell should be validated before deep adapter work begins.

For early implementation, prefer runnable macOS app slices over package extraction or premature modularization.

## Architecture Rules

- Use an adapter-based architecture, not direct feature-specific glue.
- Keep shell logic separate from integration logic.
- Normalize external systems into shared internal models.
- Treat the local store as primary for UI responsiveness.
- Make every integration degrade cleanly when disconnected or unauthorized.
- Never let a broken adapter block the shell.

## UI Rules

- Preserve the notch-first interaction model.
- Match real notch geometry where possible.
- Prefer calm, premium motion over flashy animation.
- Use haptics meaningfully and sparingly.
- Keep the closed state glanceable and low-noise.

Do not copy Boring Notch branding or assets directly. Match interaction quality, not product identity.

## Integration Rules

### Stable first

Use the cleanest integrations first:

- EventKit for Calendar
- local-first Pomodoro
- configured localhost probes
- local-first habits / learnings
- Notion sync after local models are stable

### Agent monitoring

Treat agent integrations by confidence level:

- OpenClaw gateway: strongest structured integration when available
- Claude Code: local observer first, hooks second
- Codex: local observer first, wrapper/emitter later if needed

Do not assume undocumented runtime APIs exist.

## Change Discipline

- When adding a new module, update the relevant planning docs if the scope changes.
- When adding a new adapter, document:
  - source of truth
  - auth or permission model
  - refresh strategy
  - fallback behavior
- Keep documentation aligned with implementation.

## Good First Implementation Targets

The best early milestone is:

- working notch shell
- one closed-state summary row
- one open-state panel
- Pomodoro
- Calendar next event
- 2 to 3 localhost services

Use that milestone to validate whether the notch is actually useful before expanding further.

## Early Delivery Bias

For Phase 0 and early Phase 1 work:

- prefer a runnable Xcode macOS app target
- add unit and UI test targets immediately
- optimize for real shell validation on hardware
- postpone package extraction until the shell and core behavior are proven
