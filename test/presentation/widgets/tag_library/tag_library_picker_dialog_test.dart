import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_picker_dialog.dart';

import '../../../helpers/light_theme_contrast.dart';

void main() {
  testWidgets('320 宽 3x 字体与 IME 下使用 SafeArea bottom sheet 且无溢出', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildTestApp(
        textScaler: const TextScaler.linear(3),
        entries: _entries(),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final surfaceRect = tester.getRect(surface);
    expect(surfaceRect.left, greaterThanOrEqualTo(0));
    expect(surfaceRect.top, greaterThanOrEqualTo(24));
    expect(surfaceRect.right, lessThanOrEqualTo(320));
    expect(surfaceRect.bottom, lessThanOrEqualTo(900 - 220));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TagLibraryPickerDialog), findsNothing);
  });

  for (final (width, surfaceKey) in [
    (700.0, 'adaptive-bottom-sheet'),
    (1200.0, 'adaptive-centered-form'),
  ]) {
    testWidgets('$width 宽度使用有界共享选择面并返回所选条目', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final entries = _entries();
      TagLibraryEntry? selected;

      await tester.pumpWidget(
        _buildTestApp(
          entries: entries,
          onSelected: (entry) => selected = entry,
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      final surface = find.byKey(ValueKey(surfaceKey));
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThan(width));
      expect(tester.getSize(surface).width, lessThanOrEqualTo(800));
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('tag-library-picker-entry-entry-1')),
      );
      await tester.pumpAndSettle();

      expect(selected, entries[1]);
      expect(find.byType(TagLibraryPickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

List<TagLibraryEntry> _entries() => [
  for (var index = 0; index < 8; index++)
    TagLibraryEntry.create(
      name: '预设 $index',
      content: '1girl, preset $index',
    ).copyWith(id: 'entry-$index'),
];

Widget _buildTestApp({
  required List<TagLibraryEntry> entries,
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<TagLibraryEntry?>? onSelected,
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWith(
        (ref) => InMemoryLocalStorageService(),
      ),
      tagLibraryPageNotifierProvider.overrideWith(
        () => _TestTagLibraryPageNotifier(entries),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final selected = await TagLibraryPickerDialog.show(context);
              onSelected?.call(selected);
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  _TestTagLibraryPageNotifier(this.entries);

  final List<TagLibraryEntry> entries;

  @override
  TagLibraryPageState build() => TagLibraryPageState(entries: entries);
}
