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
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_viewport_hive_');
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

  group('dialog', () {
    testWidgets('reopens every column at its last browse position', (
      tester,
    ) async {
      final harness = _Harness(tester, _dialogFixture());
      await harness.show(const FixedTagsDialog(), size: const Size(1180, 800));

      _browseList(tester, FixedTagPromptType.positive).jumpTo(600);
      _browseList(tester, FixedTagPromptType.negative).jumpTo(200);
      await tester.pump();

      await harness.close();
      await harness.show(
        const FixedTagsDialog(),
        size: const Size(1180, 800),
        settle: false,
      );
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 600);
      expect(_browseList(tester, FixedTagPromptType.negative).offset, 200);
      await tester.pumpAndSettle();
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 600);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtered views start at the top and hand the browse '
        'position back', (tester) async {
      final harness = _Harness(tester, _dialogFixture());
      await harness.show(const FixedTagsDialog(), size: const Size(1180, 800));
      _browseList(tester, FixedTagPromptType.positive).jumpTo(600);
      await tester.pump();

      final enabledOnly = find.byKey(const ValueKey('fixed-tags-enabled-only'));
      await tester.tap(enabledOnly);
      await tester.pumpAndSettle();
      final filtered = _filteredList(tester, FixedTagPromptType.positive);
      expect(filtered.offset, 0);
      filtered.jumpTo(120);
      await tester.pump();

      await tester.tap(enabledOnly);
      await tester.pumpAndSettle();
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 600);

      final positiveSearch = find.byType(TextField).first;
      await tester.enterText(positiveSearch, 'positive-1');
      await tester.pumpAndSettle();
      expect(_filteredList(tester, FixedTagPromptType.positive).offset, 0);
      await tester.enterText(positiveSearch, '');
      await tester.pumpAndSettle();
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 600);

      await harness.close();
      await harness.show(const FixedTagsDialog(), size: const Size(1180, 800));
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 600);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact tabs keep separate positions and reopen on the '
        'last tab', (tester) async {
      final harness = _Harness(tester, _dialogFixture());
      await harness.show(const FixedTagsDialog(), size: const Size(400, 800));
      _browseList(tester, FixedTagPromptType.positive).jumpTo(500);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-negative')),
      );
      await tester.pumpAndSettle();
      expect(_browseList(tester, FixedTagPromptType.negative).offset, 0);
      _browseList(tester, FixedTagPromptType.negative).jumpTo(300);
      await tester.pump();

      await harness.close();
      await harness.show(const FixedTagsDialog(), size: const Size(400, 800));
      expect(_browseListFinder(FixedTagPromptType.positive), findsNothing);
      expect(_browseList(tester, FixedTagPromptType.negative).offset, 300);

      await tester.tap(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-positive')),
      );
      await tester.pumpAndSettle();
      expect(_browseList(tester, FixedTagPromptType.positive).offset, 500);
      expect(tester.takeException(), isNull);
    });

    for (final size in [const Size(1180, 800), const Size(400, 800)]) {
      testWidgets('closing through the presented route keeps the position '
          '(${size.width.toInt()} wide)', (tester) async {
        final harness = _Harness(tester, _dialogFixture());
        await harness.show(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => FixedTagsDialog.show(context),
              child: const Text('open'),
            ),
          ),
          size: size,
        );
        final open = find.text('open');

        await tester.tap(open);
        await tester.pumpAndSettle();
        _browseList(tester, FixedTagPromptType.positive).jumpTo(450);
        await tester.pump();
        await tester.tap(find.byTooltip('关闭').last);
        await tester.pumpAndSettle();
        expect(_browseListFinder(FixedTagPromptType.positive), findsNothing);

        await tester.tap(open);
        await tester.pump();
        expect(_browseList(tester, FixedTagPromptType.positive).offset, 450);
        await tester.pumpAndSettle();
        expect(_browseList(tester, FixedTagPromptType.positive).offset, 450);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sidebar', () {
    testWidgets('reopens at the last browse position with folders still '
        'collapsed', (tester) async {
      final fixture = _sidebarFixture();
      final harness = _Harness(tester, fixture.storage);
      await harness.show(const FixedTagsSidebar(), size: _sidebarSize);

      await tester.tap(_sectionHeader(fixture.firstCategory));
      await tester.pumpAndSettle();
      expect(_sectionBody(fixture.firstCategory), findsNothing);
      _sidebarBrowseList(tester).jumpTo(400);
      await tester.pump();

      await harness.close();
      await harness.show(
        const FixedTagsSidebar(),
        size: _sidebarSize,
        settle: false,
      );
      expect(_sidebarBrowseList(tester).offset, 400);
      await tester.pumpAndSettle();
      expect(_sidebarBrowseList(tester).offset, 400);
      await tester.drag(_sidebarBrowseListFinder, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(_sectionHeader(fixture.firstCategory), findsOneWidget);
      expect(_sectionBody(fixture.firstCategory), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search and enabled-only start fresh without dropping '
        'hidden folder state', (tester) async {
      final fixture = _sidebarFixture();
      final harness = _Harness(tester, fixture.storage);
      await harness.show(const FixedTagsSidebar(), size: _sidebarSize);

      await tester.tap(_sectionHeader(fixture.firstCategory));
      await tester.pumpAndSettle();
      _sidebarBrowseList(tester).jumpTo(300);
      await tester.pump();

      final enabledOnly = find.byKey(
        const ValueKey('fixed-tags-positive-enabled-only'),
      );
      await tester.tap(enabledOnly);
      await tester.pumpAndSettle();
      expect(_sectionHeader(fixture.firstCategory), findsNothing);
      expect(_sidebarFilteredList(tester).offset, 0);
      _sidebarFilteredList(tester).jumpTo(80);
      await tester.pump();

      await tester.tap(enabledOnly);
      await tester.pumpAndSettle();
      expect(_sidebarBrowseList(tester).offset, 300);

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();
      expect(_sidebarFilteredList(tester).offset, 0);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(_sidebarBrowseList(tester).offset, 300);

      _sidebarBrowseList(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(_sectionHeader(fixture.firstCategory), findsOneWidget);
      expect(_sectionBody(fixture.firstCategory), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

const _sidebarSize = Size(340, 620);

class _Harness {
  _Harness(this.tester, LocalStorageService storage)
    : container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      ) {
    addTearDown(container.dispose);
  }

  final WidgetTester tester;
  final ProviderContainer container;

  Future<void> show(Widget surface, {required Size size, bool settle = true}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    return _pump(SizedBox.fromSize(size: size, child: surface), settle);
  }

  Future<void> close() => _pump(const SizedBox.shrink(), true);

  Future<void> _pump(Widget body, bool settle) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InteractionPolicyScope(
              initialPolicy: const InteractionPolicy(
                modality: InteractionModality.pointer,
                touchAvailable: false,
                precisePointerAvailable: true,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}

Finder _browseListFinder(FixedTagPromptType promptType) =>
    find.byKey(ValueKey('fixed-tags-${promptType.name}-browse-list'));

ScrollController _browseList(
  WidgetTester tester,
  FixedTagPromptType promptType,
) => tester
    .widget<ReorderableListView>(_browseListFinder(promptType))
    .scrollController!;

ScrollController _filteredList(
  WidgetTester tester,
  FixedTagPromptType promptType,
) => tester
    .widget<ListView>(
      find.byKey(ValueKey('fixed-tags-${promptType.name}-filtered-list')),
    )
    .controller!;

final _sidebarBrowseListFinder = find.byKey(
  const ValueKey('fixed-tags-positive-group-list'),
);

ScrollController _sidebarBrowseList(WidgetTester tester) =>
    tester.widget<CustomScrollView>(_sidebarBrowseListFinder).controller!;

ScrollController _sidebarFilteredList(WidgetTester tester) => tester
    .widget<CustomScrollView>(
      find.byKey(const ValueKey('fixed-tags-positive-filtered-group-list')),
    )
    .controller!;

Finder _sectionHeader(TagLibraryCategory category) =>
    find.byKey(ValueKey('fixed-tags-positive-group-${category.id}'));

Finder _sectionBody(TagLibraryCategory category) =>
    find.byKey(ValueKey('fixed-tags-positive-group-${category.id}-body'));

_ViewportTestStorage _dialogFixture() => _ViewportTestStorage(
  entries: [
    for (final promptType in FixedTagPromptType.values)
      for (var index = 0; index < 60; index++)
        FixedTagEntry.create(
          name: '${promptType.name}-$index',
          content: 'tag $index',
          promptType: promptType,
          enabled: index.isEven,
          sortOrder: index,
        ),
  ],
  categories: const [],
);

({_ViewportTestStorage storage, TagLibraryCategory firstCategory})
_sidebarFixture() {
  // 首个分类全部停用：仅显示已启用时它整组隐藏，用来检验折叠状态不被清理。
  final categories = [
    for (final (index, name) in ['alpha', 'beta', 'gamma'].indexed)
      TagLibraryCategory.create(name: name, sortOrder: index),
  ];
  return (
    storage: _ViewportTestStorage(
      entries: [
        for (final (categoryIndex, category) in categories.indexed)
          for (var index = 0; index < 30; index++)
            FixedTagEntry.create(
              name: '${category.name}-$index',
              content: '${category.name} tag $index',
              enabled: categoryIndex > 0 && index.isEven,
              categoryId: category.id,
              sortOrder: categoryIndex * 30 + index,
            ),
        FixedTagEntry.create(
          name: 'negative',
          content: 'lowres',
          promptType: FixedTagPromptType.negative,
        ),
      ],
      categories: categories,
    ),
    firstCategory: categories.first,
  );
}

class _ViewportTestStorage extends LocalStorageService {
  _ViewportTestStorage({required this.entries, required this.categories});

  final List<FixedTagEntry> entries;
  final List<TagLibraryCategory> categories;
  String _linksJson = '[]';
  double _negativeHeight = 180.0;

  @override
  bool getFixedTagsSidebarExpanded() => true;

  @override
  double getFixedTagsSidebarWidth() => 320.0;

  @override
  String getFixedTagsSidebarViewMode() => 'list';

  @override
  double getFixedTagsNegativeHeight() => _negativeHeight;

  @override
  Future<void> setFixedTagsNegativeHeight(double height) async {
    _negativeHeight = height;
  }

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getFixedTagsJson() =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());

  @override
  Future<void> setFixedTagsJson(String json) async {}

  @override
  String? getFixedTagLinksJson() => _linksJson;

  @override
  Future<void> setFixedTagLinksJson(String json) async {
    _linksJson = json;
  }

  @override
  String? getTagLibraryEntriesJson() => '[]';

  @override
  String? getTagLibraryCategoriesJson() =>
      jsonEncode(categories.map((category) => category.toJson()).toList());

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getHighlightEmphasis() => false;
}
