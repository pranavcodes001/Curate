# Project Architecture (Feature-first)

This document describes the proposed folder architecture and navigation approach for the app.

Goals:
- Organize by feature, not by widget-type
- Keep features isolated and easy to test
- Make it easy to add future features (search, saved threads, more guided flows)

Folder layout (top-level under `lib/src`):
- core/: App-level concerns (routing, models, utilities)
- features/: Each feature is self-contained (feed, story_detail, explore_discussion, summary, guided_questions)

Feature subfolders:
- data/: data sources and adapters (remote/local) — interfaces only for now
- domain/: models, repository interfaces and use-case contracts
- presentation/: routing declarations, pages (UI kept out for now), and presentation contracts

Navigation:
- Use a single source of route names in `core/navigation/app_routes.dart` and a central `AppRouter` skeleton.
- Prefer typed route argument classes defined in `core/models/route_arguments.dart`.
- Keep route guards (e.g., consent to enable Explore Discussion) in `core/navigation/route_guard.dart`.

Feature responsibilities (examples):
- Feed: raw feed (read-only) — lists story previews
- Story Detail: full story view and hooks to summary and explore flows
- Summary: read-only summaries provided by backend (shared by story detail & exploration)
- Explore Discussion: opt-in guided exploration flows (AI logic isolated here in the future)
- Guided Questions: domain modeling for reusable guided prompts

Notes:
- No UI, state management, or API calls are included at this stage. This scaffolding prepares for those layers.
- When choosing a state management approach later, each feature should provide a clear boundary for which types (controllers, providers, blocs) it exposes.