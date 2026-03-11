# Notch- Docs Index

This directory is organized by document role, not by document age.

Use this index as the canonical entrypoint before starting new work.

## Read This First

1. [Product requirements](./prd/ultimate-notch-app-prd.md)
2. [Current implementation state](./architecture/current-state.md)
3. [Repository structure](./architecture/repository-structure.md)
4. [Build plan](./architecture/build-plan.md)
5. [Adapter architecture](./architecture/adapter-architecture.md)

## Active Build References

- [Phase 0 shell research](./research/phase-0-shell-research.md)
- [Integration research](./research/integration-research.md)
- [Integration matrix](./research/integration-matrix.md)
- [Boring Notch settings research](./research/boring-notch-settings-research.md)

## Reference Material

- [Boring Notch reference analysis](./reference/boring-notch-analysis.md)
- [Boring Notch source map](./reference/boring-notch-source-map.md)

Use reference docs to extract patterns and constraints. Do not treat them as the build sequence.

## Historical Decisions

- [Runnable shell first decision](./archive/2026-03-09-runnable-shell-first-design.md)

Historical docs explain why a decision was made. They should not override the current build plan or current-state document.

## Directory Roles

- `prd/`: product requirements and scope boundaries
- `architecture/`: active implementation guidance and project state
- `research/`: supporting technical guidance used during implementation
- `reference/`: external pattern analysis and competitive/reference breakdowns
- `archive/`: older decisions retained for context

## Working Rules

- Update [current-state](./architecture/current-state.md) when implementation meaningfully changes phase status or completed scope.
- Update [repository structure](./architecture/repository-structure.md) when folders or ownership boundaries change.
- Keep shell viewport and interaction behavior documented in current-state when the open-shell model changes.
- Update [build-plan](./architecture/build-plan.md) when sequencing changes.
- Update the PRD only when product scope or boundaries change.
- Keep reference and archive docs out of the critical path unless they are directly relevant to the task.
