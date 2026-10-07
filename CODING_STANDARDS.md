# Coding Standards

## Validation
- Prefer one named XCTest: `xcodebuild test -project Notch-.xcodeproj -scheme Notch- -only-testing:<target>/<test>`.
- For shell-only work, validate the runnable slice or directly affected target.
- Complete unit/UI tests, full builds, and all integration checks are broad and run only after an explicit user request.

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

## Early Delivery Bias

For Phase 0 and early Phase 1 work:

- prefer a runnable Xcode macOS app target
- add unit and UI test targets immediately
- optimize for real shell validation on hardware
- postpone package extraction until the shell and core behavior are proven
