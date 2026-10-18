# Notch- Agent Contract

## Boundaries

- Preserve notch-first, local-first, adapter-based product boundaries.
- Match interaction quality while keeping Boring Notch branding and assets separate.

## Task references

- Domain routing: read [domain.md](docs/agents/domain.md).

- Code or adapter changes, reviews, or validation: read [CODING_STANDARDS.md](CODING_STANDARDS.md).
- Product scope, implementation sequencing, research, or architecture: read only relevant documents listed in [agent-contract-legacy.md](docs/agents/agent-contract-legacy.md).

## File size

- Keep every source file at or below 500 LOC. Tests, docs and CSS are exempt. Markdown is documentation, not source. Split a source file before completion if your change takes it over the limit.
- Hooks activate automatically on managed development accounts and new Codex environments. Pre-commit checks only staged authored text: at most 5,000 tokens (bytes / 4). See [.githooks/README.md](.githooks/README.md) for generated-file exemptions and splitting instructions.
