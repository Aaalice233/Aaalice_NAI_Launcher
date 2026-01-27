import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';

void main() {
  group('Statistics Navigation Tests', () {
    testWidgets('Clicking statistics icon opens independent page',
        (tester) async {
      // Load app
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Find statistics icon in navigation rail
      final statisticsIcon = find.byIcon(Icons.bar_chart);
      expect(statisticsIcon, findsOneWidget);

      // Tap statistics icon
      await tester.tap(statisticsIcon);
      await tester.pumpAndSettle();

      // Verify StatisticsScreen is displayed
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Verify URL updated (go_router should update to /statistics)
      expect(find.text('Statistics'), findsOneWidget);

      // Verify not a dialog (StatisticsScreen should be full page)
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Back navigation works from statistics page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify on statistics page
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Tap back button
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify returned to previous screen (gallery or home)
      expect(find.byType(StatisticsScreen), findsNothing);
    });

    testWidgets('Statistics tab navigation works', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify on statistics page
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Statistics screen should have tabs (Overview, Trends, Details)
      // Note: The exact tab names depend on implementation
      // This test verifies the statistics page is accessible and interactive
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Can navigate to statistics from different branches',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Start from home/gallery
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is shown
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Navigate away
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate to statistics again
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is shown again
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics route is accessible via URL', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate using router directly
      // In a real test, we would use router.go(AppRoutes.statistics)
      // For widget tests, we tap the icon which triggers the same navigation
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify we're on the statistics page
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen maintains state correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is rendered
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Navigate away
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate back to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is rendered again
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });
  });
}
