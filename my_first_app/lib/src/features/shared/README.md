Shared utilities for features

Responsibility:
- Host shared types, small utilities, and adapters that are feature-agnostic.
- Examples: pagination helpers, date formatters, small value objects.

Important:
- Do NOT place cross-cutting UI components here; prefer `core/widgets` later if needed.
- Keep coupling minimal between features.