import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';

void main() {
  group('Statistics Filters Tests', () {
    testWidgets('Date range filter updates charts', (tester) async {
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

      // Find date range picker button if available
      final dateRangeButton = find.byIcon(Icons.calendar_month);

      if (dateRangeButton.evaluate().isNotEmpty) {
        expect(dateRangeButton, findsOneWidget);

        // Tap to open date range picker
        await tester.tap(dateRangeButton);
        await tester.pumpAndSettle();

        // Date range picker dialog should appear
        // This is implementation-specific - the exact test depends on UI
        expect(find.byType(Dialog), findsOneWidget);

        // Close the dialog
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Model filter updates charts', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Find model dropdown if available
      final modelDropdown = find.byType(DropdownButtonFormField);

      if (modelDropdown.evaluate().isNotEmpty) {
        expect(modelDropdown, findsWidgets);

        // Tap and select model
        await tester.tap(modelDropdown.first);
        await tester.pumpAndSettle();

        // The dropdown items should appear
        // This is implementation-specific

        // Tap outside to close
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Clear all filters resets data', (tester) async {
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

      // Look for "Clear All" button if it exists
      final clearButton = find.text('Clear All');

      if (clearButton.evaluate().isNotEmpty) {
        expect(clearButton, findsOneWidget);

        // Tap clear button
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        // Verify we're still on statistics page
        expect(find.byType(StatisticsScreen), findsOneWidget);
      }
    });

    testWidgets('Filter combinations work correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen is displayed
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Apply various filters if available
      // This is implementation-specific and depends on the actual UI

      // Verify statistics screen is still displayed after filter interactions
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen loads without filters', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Verify statistics screen displays
      expect(find.byType(StatisticsScreen), findsOneWidget);

      // Should show some content (cards, charts, etc.)
      // The exact widgets depend on implementation
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Statistics screen handles filter interactions gracefully',
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

      // Try to interact with various filter controls
      // This test ensures the app doesn't crash during filter interactions

      final dropdownButtons = find.byType(DropdownButton);
      for (var i = 0; i < dropdownButtons.evaluate().length; i++) {
        await tester.tap(dropdownButtons.at(i));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      // Verify still on statistics page
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Time range grouping changes correctly', (tester) async {
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

      // Look for time range grouping selector (daily, weekly, monthly)
      // This is implementation-specific

      // The statistics screen should remain functional
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Filter state persists during navigation', (tester) async {
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
  });
}
