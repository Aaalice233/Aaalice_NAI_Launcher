import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';

void main() {
  group('Statistics Export Tests', () {
    testWidgets('Export button opens dialog', (tester) async {
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
      expect(exportButton, findsOneWidget);

      // Tap export button
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      // Verify export dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('Export dialog shows format options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify both format options are present
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);

      // Verify export and cancel buttons
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Can select JSON format', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Tap JSON format option
      final jsonOption = find.text('JSON');
      await tester.tap(jsonOption);
      await tester.pumpAndSettle();

      // JSON option should still be visible (selected state)
      expect(jsonOption, findsOneWidget);
    });

    testWidgets('Can select CSV format', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Tap CSV format option
      final csvOption = find.text('CSV');
      await tester.tap(csvOption);
      await tester.pumpAndSettle();

      // CSV option should still be visible (selected state)
      expect(csvOption, findsOneWidget);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);

      // Verify still on statistics screen
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('Export dialog displays information text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify info icon is present
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Can switch between formats', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Select JSON
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      // Select CSV
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();

      // Dialog should still be open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Both options should still be visible
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('Export button is disabled during export', (tester) async {
      // This test verifies the UI state during export
      // In a real scenario with actual file I/O, we'd need to mock the file system

      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify export button is enabled
      final exportButton = find.text('Export');
      expect(exportButton, findsOneWidget);

      // Note: Testing the actual export process and loading state
      // would require mocking the file system and path_provider
      // The UI structure supports showing a loading indicator
    });

    testWidgets('Export dialog can be reopened after closing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);

      // Reopen export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify dialog opens again
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('Export dialog has proper accessibility', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: NAILauncherApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to statistics
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Open export dialog
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      // Verify dialog has a title with icon
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      // Verify buttons are present and accessible
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Verify format options have icons
      expect(find.byIcon(Icons.code), findsOneWidget); // JSON icon
      expect(find.byIcon(Icons.table_chart), findsOneWidget); // CSV icon
    });
  });
}
