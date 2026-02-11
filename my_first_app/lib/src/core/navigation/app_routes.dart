// App-level route constants and argument classes
// Responsibility: Provide a single source of truth for route names and typed route arguments.

// NOTE: Keep these stable — changing route names is a breaking change for
// deep-linking and analytics.

/// Primary feed — shows raw Hacker News feed (read-only).
/// When used: app launch, or when user navigates to feed.
/// Not opt-in; purely read-only.
const String routeFeed = '/feed';

/// Story detail — shows a single story and its metadata.
/// When used: from Feed or deep-link to see a single story.
/// Not opt-in; read-only. Connects to Summary and Explore flows via explicit actions.
const String routeStoryDetail = '/story';

/// Explore discussion — opt-in, guided AI exploration flow.
/// When used: launched only after explicit user action ("Explore discussion").
/// Opt-in: YES. Route should be guarded by consent checks; no automatic redirects.
const String routeExploreDiscussion = '/story/explore';

/// Summary view — shows a backend-provided read-only summary for a story.
/// When used: launched from Story Detail or Explore flows when user requests summary.
/// Opt-in: NOT required (summary is read-only), but should respect user preferences.
const String routeSummary = '/story/summary';

/// Login
const String routeLogin = '/auth/login';

/// Saved threads list
const String routeSavedThreads = '/saved_threads';

// Use typed route argument classes from `core/models/route_arguments.dart` to
// provide strong contract guarantees when navigating between features.
