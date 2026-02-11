// AppRouter skeleton
// Responsibility: Central place to wire navigation (RouterDelegate / Navigator 2.0 or Navigator 1.0 wrappers).

// This file provides a lightweight registration contract for routes that
// features can use to register themselves with the router. It intentionally
// avoids any UI types (no Pages or Widgets) so the registry remains testable
// and independent of the Navigator approach chosen later.

/// Descriptor that documents a route's contract for registration.
/// `optIn` indicates flows that require explicit user consent (e.g., AI exploration).
class RouteDescriptor {
  final String name;
  final String description;
  final String argsClassName;
  final bool optIn; // set true for routes that require explicit opt-in/consent

  const RouteDescriptor({required this.name, required this.description, required this.argsClassName, this.optIn = false});
}

/// Example route registrations. Features should register their descriptors
/// during app startup (app-level wiring) so the router and any tooling can
/// discover available routes without loading UI code.
///
/// Note about protecting "AI is opt-in":
/// - `ExploreDiscussion` is registered with `optIn: true` to indicate it must
///   be entered only after explicit consent. Route guards should consult this
///   metadata and surface consent flows before navigation.
const List<RouteDescriptor> registeredRoutes = [
  RouteDescriptor(
    name: '/feed',
    description: 'Feed list (raw, read-only)',
    argsClassName: 'FeedRouteArgs',
    optIn: false,
  ),
  RouteDescriptor(
    name: '/story',
    description: 'Story detail view',
    argsClassName: 'StoryDetailRouteArgs',
    optIn: false,
  ),
  RouteDescriptor(
    name: '/story/explore',
    description: 'Explore discussion (guided AI, opt-in)',
    argsClassName: 'ExploreDiscussionRouteArgs',
    optIn: true, // explicit consent required
  ),
  RouteDescriptor(
    name: '/story/summary',
    description: 'Summary view (read-only)',
    argsClassName: 'SummaryRouteArgs',
    optIn: false,
  ),
];

// When implementing the Router (either 1.0 or 2.0), consult `registeredRoutes`
// for route information and opt-in flags. A route guard should use this
// metadata to decide whether a consent flow must run before actually pushing a
// route that is `optIn: true`.
