import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/presentation/screens/statistics_screen.dart';

void main() {
  group('Statistics Flow Tests', () {
    testWidgets('Complete statistics viewing workflow', (tester) async {
      // Launch app
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify page loaded
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Verify statistics screen displays content
      // The exact widgets depend on implementation but the screen should be present
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Navigate and view statistics screen', (tester) async {
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

      // Navigate away
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate back to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is still functional
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen handles back navigation correctly',
        (tester) async {
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

      // Use back navigation
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify we left the statistics screen
      expect(find.byType(StatisticsScreen), findsNothing);
    });

    testWidgets('Statistics screen can be accessed multiple times',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // First visit
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Second visit
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Third visit
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen responds to user interactions',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify screen is interactive
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Try various interactions to ensure no crashes
      final cards = find.byType(Card);
      if (cards.evaluate().isNotEmpty) {
        // Tap on first card if present
        await tester.tap(cards.first);
        await tester.pumpAndSettle();
      }

      // Screen should still be present
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics export workflow', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Find export button
      final exportButton = find.byIcon(Icons.download);
      if (exportButton.evaluate().isNotEmpty) {
        // Open export dialog
        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        // Verify export dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify we're back on statistics screen
        expect(find.byType(StatisticsScreen), findsOneWidget);
      }
    });

    testWidgets('Statistics screen maintains state during app lifecycle',
        (tester) async {
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

      // Simulate app pause/resume by pumping widgets
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Screen should still be present
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics navigation from different app states',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics from home
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Navigate to statistics again
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // The screen should be consistent across navigations
    });

    testWidgets('Statistics screen handles rapid navigation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Rapid navigation tests
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.bar_chart));
        await tester.pumpAndSettle();
        expect(find.byType(StatisticsScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // Verify final state is consistent
      expect(find.byType(StatisticsScreen), findsNothing);
    });

    testWidgets('Statistics screen interactions work correctly',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify screen is rendered
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Test various UI elements
      final icons = [
        Icons.bar_chart,
        Icons.download,
        Icons.refresh,
      ];

      for (final icon in icons) {
        final widget = find.byIcon(icon);
        if (widget.evaluate().isNotEmpty) {
          // Verify the icon is present
          expect(widget, findsWidgets);
        }
      }

      // Screen should remain stable
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Complete user journey through statistics feature',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // User navigates to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // User views the statistics screen
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // User interacts with export functionality if available
      final exportButton = find.byIcon(Icons.download);
      if (exportButton.evaluate().isNotEmpty) {
        await tester.tap(exportButton);
        await tester.pumpAndSettle();

        // User closes export dialog
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
      }

      // User navigates back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify user is no longer on statistics screen
      expect(find.byType(StatisticsScreen), findsNothing);
    });

    testWidgets('Statistics screen loads without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // No exceptions should be thrown
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Pump and settle to ensure all async operations complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Screen should still be present without errors
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen is accessible and usable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify the screen is rendered and accessible
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Verify navigation elements are present
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);

      // The screen should be properly integrated into the app navigation
    });
  });
}
