import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_selector_dialog.dart';

void main() {
  final category = TagLibraryCategory(
    id: 'people',
    name: '人物',
    createdAt: DateTime(2026),
  );
  final entries = [
    TagLibraryEntry(
      id: 'entry-1',
      name: '第一条目',
      content: '1girl, portrait',
      categoryId: category.id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    TagLibraryEntry(
      id: 'entry-2',
      name: '第二条目',
      content: '1boy, landscape',
      tags: const ['目标标签'],
      categoryId: category.id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  testWidgets(
    '320px 3x text SafeArea and IME keep search, selection and confirm reachable',
    (tester) async {
      await _setCompactImeViewport(tester);
      TagLibraryEntry? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await EntrySelectorDialog.show(
                  context,
                  entries: entries,
                  categories: [category],
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(panel, findsOneWidget);
      final panelRect = tester.getRect(panel);
      expect(panelRect.top, greaterThanOrEqualTo(24));
      expect(panelRect.bottom, lessThanOrEqualTo(500));

      await tester.enterText(find.byType(TextField), '目标标签');
      await tester.pump();
      expect(find.text('第一条目'), findsNothing);
      expect(find.text('第二条目'), findsOneWidget);

      await tester.ensureVisible(find.text('第二条目'));
      await tester.tap(find.text('第二条目'));
      final confirm = find.text('更新预览图');
      await tester.drag(
        find.byKey(const Key('entry-selector-scroll')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(result, entries[1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medium width uses bounded adaptive form and system back cancels',
    (tester) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var completed = false;
      TagLibraryEntry? result = entries.first;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await EntrySelectorDialog.show(
                  context,
                  entries: entries,
                  categories: [category],
                );
                completed = true;
              },
              child: const Text('打开'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(panel, findsOneWidget);
      expect(tester.getSize(panel).width, lessThanOrEqualTo(700));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setCompactImeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = const FakeViewPadding(bottom: 220);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    autocompleteSettingsProvider.overrideWith(
      (ref) => _DisabledAutocompleteSettingsNotifier(),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(3)),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);

class _DisabledAutocompleteSettingsNotifier
    extends AutocompleteSettingsNotifier {
  _DisabledAutocompleteSettingsNotifier() : super(LocalStorageService()) {
    state = const AutocompleteSettings(
      enabled: false,
      danbooruEnabled: false,
      zhInstallPromptDismissed: true,
    );
  }
}
