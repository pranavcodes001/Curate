// Typed route argument placeholders
// Responsibility: Define argument classes for navigation to avoid fragile positional args.
//
// These classes are deliberately lightweight, serializable, and contain only the
// data needed to navigate. They are NOT responsible for validation, UI, or
// business logic.

/// Arguments for opening the Feed view.
/// When used: primary entry point that shows the raw feed.
/// Optional fields allow safe expansion (paging / filters) without changing the
/// navigation contract.
class FeedRouteArgs {
  /// Optional page number for paginated feeds.
  final int? page;

  const FeedRouteArgs({this.page});
}

/// Arguments for Story Detail.
/// When used: navigated to from the Feed or deep-links to show a single story.
/// Required: [hnId] identifies the Hacker News story.
/// Optional: [title] and [source] are helpful for presentation and route previews.
class StoryDetailRouteArgs {
  final String hnId;
  final String? title;
  final String? source;

  const StoryDetailRouteArgs({required this.hnId, this.title, this.source});
}

/// Arguments for Explore Discussion (OPT-IN flow).
/// When used: launched explicitly by user action ("Explore discussion") from
/// Story Detail. This flow is opt-in and may require explicit user consent
/// before entering (see route guard).
/// [entryContext] indicates the user's navigation origin (e.g., "story_detail").
class ExploreDiscussionRouteArgs {
  final String hnId;
  final String entryContext;
  final String? title;
  /// Optional flag for whether user has already provided in-session consent.
  /// Route guard should still verify consent before allowing the flow.
  final bool? userConsentProvided;

  const ExploreDiscussionRouteArgs({
    required this.hnId,
    required this.entryContext,
    this.title,
    this.userConsentProvided,
  });
}

/// Arguments for Summary view (read-only summary endpoint).
/// When used: requested from Story Detail or Explore flows to present the
/// backend-provided summary. [modelVersion] is optional and allows explicit
/// version selection if needed in the future.
class SummaryRouteArgs {
  final String hnId;
  final String? modelVersion;
  final SummaryTargetType targetType;

  const SummaryRouteArgs({
    required this.hnId,
    this.modelVersion,
    this.targetType = SummaryTargetType.story,
  });
}

enum SummaryTargetType { story, comment }

// Keep these serializable if deep linking is required in the future.
