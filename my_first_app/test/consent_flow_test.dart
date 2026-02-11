import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/app.dart';
import 'package:my_first_app/src/core/navigation/route_guard.dart';
import 'package:my_first_app/src/core/navigation/app_routes.dart';
import 'package:my_first_app/src/core/models/route_arguments.dart';

// Widget tests for consent gating behavior
// These tests validate the core trust invariants:
// - Explore Discussion is opt-in and requires user consent (session-scoped)
// - Summary remains accessible without consent
// They intentionally avoid any real backend or persistent storage.

void main() {
  setUp(() {
    // Ensure consent is cleared between tests (session-only storage)
    ConsentService.instance.clearConsent();
  });

  testWidgets('Tapping Explore shows consent dialog and accepting navigates to Explore', (tester) async {
    await tester.pumpWidget(const App());

    // Navigate to Story Detail by tapping first story in Feed
    await tester.tap(find.text('Announcing ExampleProject v1'));
    await tester.pumpAndSettle();

    // Tap Explore button
    expect(find.text('Explore discussion — AI (opt-in)'), findsOneWidget);
    await tester.tap(find.text('Explore discussion — AI (opt-in)'));
    await tester.pumpAndSettle();

    // Consent dialog should appear
    expect(find.text('Explore discussion — opt in'), findsOneWidget);

    // Accept consent
    await tester.tap(find.text('Agree & explore'));
    await tester.pumpAndSettle();

    // Explore placeholder screen should be visible
    expect(find.textContaining('This is a placeholder for the guided Explore Discussion flow'), findsOneWidget);
    // Consent should be recorded for session
    expect(ConsentService.instance.consentGiven, isTrue);
  });

  testWidgets('Tapping Explore shows consent dialog and declining keeps user on Story Detail', (tester) async {
    await tester.pumpWidget(const App());

    // Navigate to Story Detail
    await tester.tap(find.text('Announcing ExampleProject v1'));
    await tester.pumpAndSettle();

    // Tap Explore button
    await tester.tap(find.text('Explore discussion — AI (opt-in)'));
    await tester.pumpAndSettle();

    // Consent dialog should appear
    expect(find.text('Explore discussion — opt in'), findsOneWidget);

    // Decline
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Still on Story Detail: summary button should be visible
    expect(find.text('Show summary (read-only)'), findsOneWidget);

    // Consent not recorded
    expect(ConsentService.instance.consentGiven, isFalse);
  });

  testWidgets('Direct navigation to Explore triggers consent dialog and declining pops back', (tester) async {
    await tester.pumpWidget(const App());

    // Navigate to Story Detail
    await tester.tap(find.text('Announcing ExampleProject v1'));
    await tester.pumpAndSettle();

    // Programmatically push the Explore route (simulate direct route navigation)
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).pushNamed(
      routeExploreDiscussion,
      arguments: ExploreDiscussionRouteArgs(hnId: '1001', entryContext: 'test'),
    );
    await tester.pumpAndSettle();

    // Consent dialog should appear
    expect(find.text('Explore discussion — opt in'), findsOneWidget);

    // Decline
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify we are back on Story Detail
    expect(find.text('Show summary (read-only)'), findsOneWidget);
    expect(ConsentService.instance.consentGiven, isFalse);
  });

  testWidgets('Summary page is accessible without consent', (tester) async {
    await tester.pumpWidget(const App());

    // Navigate to Story Detail
    await tester.tap(find.text('Announcing ExampleProject v1'));
    await tester.pumpAndSettle();

    // Tap Show summary
    await tester.tap(find.text('Show summary (read-only)'));
    await tester.pumpAndSettle();

    // Summary page content should be visible
    expect(find.textContaining('This is a short, backend-provided summary for story'), findsOneWidget);

    // Consent should still be false
    expect(ConsentService.instance.consentGiven, isFalse);
  });
}
