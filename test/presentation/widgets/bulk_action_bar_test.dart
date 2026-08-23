import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/bulk_action_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required bool pageSelected,
    required bool allSelected,
    double width = 1400,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: BulkActionBar(
              selectedCount: 12,
              isAllSelected: pageSelected,
              isAllAvailableSelected: allSelected,
              onExit: () {},
              onSelectAll: () {},
              onSelectAllAvailable: () {},
              selectAllLabel: 'Select page',
              deselectAllLabel: 'Deselect page',
              selectAllAvailableLabel: 'Select all results',
              deselectAllAvailableLabel: 'Deselect all results',
              actions: [
                BulkActionItem(
                  icon: Icons.archive_outlined,
                  label: 'Pack',
                  onPressed: () {},
                ),
                BulkActionItem(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: () {},
                  isDanger: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses distinct icons for page and all-result selection states', (
    tester,
  ) async {
    await pumpBar(tester, pageSelected: false, allSelected: false);

    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsOneWidget);

    await pumpBar(tester, pageSelected: true, allSelected: true);

    expect(find.byIcon(Icons.indeterminate_check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.remove_done), findsOneWidget);
  });

  testWidgets('keeps visible actions aligned to the trailing edge', (
    tester,
  ) async {
    await pumpBar(tester, pageSelected: false, allSelected: false);

    expect(find.text('Pack'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    final trailingButton = tester.getRect(
      find.widgetWithText(TextButton, 'Delete'),
    );
    final bar = tester.getRect(find.byType(BulkActionBar));
    expect(trailingButton.right, closeTo(bar.right - 8, 0.01));
  });

  testWidgets('uses icon-only actions on compact widths without overflow', (
    tester,
  ) async {
    await pumpBar(tester, pageSelected: false, allSelected: false, width: 900);

    expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
