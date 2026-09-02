import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/bulk_move_category_dialog.dart';

void main() {
  final categories = List.generate(
    24,
    (index) => TagLibraryCategory(
      id: 'category-$index',
      name: 'Category $index with a readable name',
      sortOrder: index,
      createdAt: DateTime(2026),
    ),
  );

  testWidgets(
    'compact 320 width uses a full-screen scrollable selection surface',
    (tester) async {
      await _pumpLauncher(
        tester,
        size: const Size(320, 640),
        categories: categories,
      );
      await _openDialog(tester);

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bulk-move-category-list')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const ValueKey('bulk-move-category-list')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Category 23 with a readable name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact selection surface supports 3x text scaling', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      size: const Size(320, 640),
      textScale: 3,
      categories: categories.take(4).toList(),
    );
    await _openDialog(tester);

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection surface avoids IME and SafeArea insets', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      size: const Size(390, 760),
      padding: const EdgeInsets.fromLTRB(12, 36, 12, 28),
      viewInsets: const EdgeInsets.only(bottom: 280),
      categories: categories.take(8).toList(),
    );
    await _openDialog(tester);

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
    );
    expect(surfaceRect.top, greaterThanOrEqualTo(36));
    expect(surfaceRect.bottom, lessThanOrEqualTo(760 - 280));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'medium and expanded layouts keep the selection surface bounded',
    (tester) async {
      for (final size in [const Size(700, 800), const Size(1180, 800)]) {
        await _pumpLauncher(
          tester,
          size: size,
          categories: categories.take(4).toList(),
        );
        await _openDialog(tester);

        final surfaceFinder = size.width < 840
            ? find.byKey(const ValueKey('adaptive-centered-form'))
            : find.byKey(const ValueKey('adaptive-side-sheet'));
        expect(surfaceFinder, findsOneWidget);
        expect(tester.getSize(surfaceFinder).width, lessThan(size.width));
        expect(tester.takeException(), isNull, reason: '$size');

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('category selection returns its existing category id', (
    tester,
  ) async {
    String? result;
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(320, 640),
      categories: categories.take(2).toList(),
      onResult: (value) {
        result = value;
        completed = true;
      },
    );
    await _openDialog(tester);

    await tester.tap(find.text('Category 1 with a readable name'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, 'category-1');
    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsNothing,
    );
  });

  testWidgets('system back dismisses without returning a category', (
    tester,
  ) async {
    String? result;
    var completed = false;
    await _pumpLauncher(
      tester,
      size: const Size(320, 640),
      categories: categories.take(2).toList(),
      onResult: (value) {
        result = value;
        completed = true;
      },
    );
    await _openDialog(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsNothing,
    );
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Size size,
  required List<TagLibraryCategory> categories,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  ValueChanged<String?>? onResult,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-bulk-move-dialog'),
              onPressed: () async {
                final result = await BulkMoveCategoryDialog.show(
                  context,
                  categories: categories,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-bulk-move-dialog')));
  await tester.pumpAndSettle();
}
