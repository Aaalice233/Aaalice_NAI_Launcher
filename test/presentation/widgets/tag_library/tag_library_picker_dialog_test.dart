import 'dart:async';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_entry_hover_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_picker_dialog.dart';

import '../../../helpers/light_theme_contrast.dart';

void main() {
  testWidgets(
    'picker reuses the fixed-tag hover preview and dismisses it on selection',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final entry = TagLibraryEntry.create(
        name: '完整预览',
        content: '${List.filled(120, 'green_hair').join(', ')}, final_tag',
      ).copyWith(id: 'preview-entry');
      final lookup = TagTranslationLookup.fromResolver(
        (tags) async => {'green_hair': '绿发', 'final_tag': '末尾标签'},
      );
      addTearDown(lookup.dispose);
      TagLibraryEntry? selected;
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          lookup: lookup,
          onSelected: (value) => selected = value,
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final card = find.byKey(
        const ValueKey('tag-library-picker-entry-preview-entry'),
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byType(TagLibraryEntryHoverPreview),
        ),
        findsOneWidget,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 699));
      expect(find.byType(TagLibraryEntryPreviewOverlay), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      final preview = find.byType(TagLibraryEntryPreviewOverlay);
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.text(entry.content)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.textContaining('末尾标签')),
        findsOneWidget,
      );
      await mouse.moveTo(tester.getCenter(preview));
      await tester.pump(const Duration(milliseconds: 200));
      expect(preview, findsOneWidget);
      final scrollable = find
          .descendant(of: preview, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(preview, findsOneWidget);
      await mouse.moveTo(tester.getCenter(card));
      await mouse.down(tester.getCenter(card));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(selected, entry);
      expect(preview, findsNothing);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('translated cards grow naturally at $width / ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final ready = Completer<void>();
        final lookup = TagTranslationLookup.fromResolver((tags) async {
          await ready.future;
          return {for (final tag in tags) tag: '这是用于验证双语预览布局的长翻译'};
        });
        addTearDown(lookup.dispose);
        final entries = List.generate(
          8,
          (index) => TagLibraryEntry.create(
            name: '长文本预设 $index',
            content:
                'limegreen_hair, green_eyes, long_hair, one_side_up, medium_breasts, black_ribbon, hair_ribbon',
          ).copyWith(id: 'entry-$index'),
        );
        TagLibraryEntry? selected;
        await tester.pumpWidget(
          _buildTestApp(
            textScaler: TextScaler.linear(scale),
            entries: entries,
            lookup: lookup,
            onSelected: (entry) => selected = entry,
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final first = find.byKey(
          const ValueKey('tag-library-picker-entry-entry-0'),
        );
        final before = tester.getSize(first).height;
        ready.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(first).height, greaterThan(before));
        final translation = find.descendant(
          of: first,
          matching: find.byKey(const ValueKey('translated-prompt-translation')),
        );
        expect(translation, findsOneWidget);
        expect(
          tester.getRect(translation).bottom,
          lessThanOrEqualTo(tester.getRect(first).bottom),
        );
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(selected, entries.first);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

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
    (700.0, 'adaptive-centered-form'),
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
  TagTranslationLookup? lookup,
}) {
  return ProviderScope(
    overrides: [
      if (lookup != null)
        tagTranslationLookupProvider.overrideWithValue(lookup),
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
