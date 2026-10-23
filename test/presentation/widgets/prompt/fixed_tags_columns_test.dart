import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog.dart';

typedef _Scenario = ({
  String name,
  Size size,
  double textScale,
  InteractionPolicy policy,
});

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_columns_hive_');
    Hive.init(hiveDir.path);
    // 内存后端：落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box
    await Hive.openBox(StorageKeys.settingsBox, bytes: Uint8List(0));
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  const scenarios = <_Scenario>[
    (
      name: 'phone width',
      size: Size(400, 800),
      textScale: 1.0,
      policy: InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    ),
    (
      name: 'desktop width at 2x text',
      size: Size(1180, 800),
      textScale: 2.0,
      policy: InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets('compact search keeps focus and input connection while '
        'filtering (${scenario.name})', (tester) async {
      await _pumpDialog(tester, scenario);
      expect(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-positive')),
        findsOneWidget,
      );

      final search = find.byType(EditableText);
      await tester.showKeyboard(search);
      await tester.pump();
      final editable = tester.state<EditableTextState>(search);
      expect(editable.widget.focusNode.hasFocus, isTrue);

      // 只往已有连接里送字，不重新聚焦：连接断了这里会直接失败。
      tester.testTextInput.enterText('alpha');
      await tester.pumpAndSettle();
      expect(_filteredList, findsOneWidget);
      expect(tester.state<EditableTextState>(search), same(editable));
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      tester.testTextInput.enterText('alpha-1');
      await tester.pumpAndSettle();
      expect(editable.textEditingValue.text, 'alpha-1');
      expect(find.text('alpha-10'), findsOneWidget);
      expect(find.text('beta-0'), findsNothing);

      tester.testTextInput.enterText('');
      await tester.pumpAndSettle();
      expect(_browseList, findsOneWidget);
      expect(tester.state<EditableTextState>(search), same(editable));
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving compact search from the field returns to the top '
        'without scrolling back (${scenario.name})', (tester) async {
      await _pumpDialog(tester, scenario);
      final search = find.byType(EditableText);
      await tester.showKeyboard(search);
      await tester.pump();
      _browseController(tester).jumpTo(600);
      await tester.pump();

      tester.testTextInput.enterText('alpha');
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('');
      await tester.pump();
      expect(_browseController(tester).offset, 0);
      await tester.pumpAndSettle();
      expect(_browseController(tester).offset, 0);
      expect(
        tester.state<EditableTextState>(search).widget.focusNode.hasFocus,
        isTrue,
      );

      _browseController(tester).jumpTo(600);
      await tester.pump();
      tester.testTextInput.enterText('alpha');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pump();
      expect(_browseController(tester).offset, 0);
      await tester.pumpAndSettle();
      expect(_browseController(tester).offset, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enabled-only round trip still restores the browse position '
        '(${scenario.name})', (tester) async {
      await _pumpDialog(tester, scenario);
      _browseController(tester).jumpTo(600);
      await tester.pump();

      final enabledOnly = find.byKey(const ValueKey('fixed-tags-enabled-only'));
      await tester.tap(enabledOnly);
      await tester.pumpAndSettle();
      expect(_filteredList, findsOneWidget);
      await tester.tap(enabledOnly);
      await tester.pump();
      expect(_browseController(tester).offset, 600);
      await tester.pumpAndSettle();
      expect(_browseController(tester).offset, 600);
      expect(tester.takeException(), isNull);
    });
  }
}

final _browseList = find.byKey(
  const ValueKey('fixed-tags-positive-browse-list'),
);
final _filteredList = find.byKey(
  const ValueKey('fixed-tags-positive-filtered-list'),
);

ScrollController _browseController(WidgetTester tester) =>
    tester.widget<ReorderableListView>(_browseList).scrollController!;

Future<void> _pumpDialog(WidgetTester tester, _Scenario scenario) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = scenario.size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => _Storage()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: scenario.policy,
            child: const FixedTagsDialog(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Storage extends LocalStorageService {
  @override
  String? getFixedTagsJson() => jsonEncode([
    for (final name in ['alpha', 'beta'])
      for (var index = 0; index < 12; index++)
        FixedTagEntry.create(
          name: '$name-$index',
          content: '$name tag',
          enabled: index.isEven,
          sortOrder: index,
        ).toJson(),
  ]);

  @override
  Future<void> setFixedTagsJson(String json) async {}

  @override
  String? getFixedTagLinksJson() => '[]';

  @override
  Future<void> setFixedTagLinksJson(String json) async {}

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getTagLibraryEntriesJson() => '[]';

  @override
  String? getTagLibraryCategoriesJson() => '[]';

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getHighlightEmphasis() => false;
}
