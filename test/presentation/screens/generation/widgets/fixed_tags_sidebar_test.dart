import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_link.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/generation_screen.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_entry_tile.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_link_painter.dart';
import 'package:nai_launcher/presentation/widgets/common/thumbnail_display.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_button.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_sidebar_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets(
      'renders enabled categorized entries without duplicate key errors',
      (tester) async {
    final category = TagLibraryCategory.create(name: '画师');
    final enabled = FixedTagEntry.create(
      name: 'artist enabled',
      content: 'artist:fuzichoco',
      categoryId: category.id,
      enabled: true,
    );
    final quality = FixedTagEntry.create(
      name: 'quality',
      content: 'masterpiece',
      categoryId: category.id,
      enabled: false,
    );
    final negative = FixedTagEntry.create(
      name: 'negative',
      content: 'bad hands',
      promptType: FixedTagPromptType.negative,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [enabled, quality, negative],
      categories: [category],
      libraryEntries: [
        TagLibraryEntry.create(
          name: enabled.name,
          content: enabled.content,
          categoryId: category.id,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('artist enabled'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('quality'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'quality');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('quality'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('artist enabled'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category chips wrap when the sidebar is narrow', (tester) async {
    final categories = [
      TagLibraryCategory.create(name: '质量词'),
      TagLibraryCategory.create(name: '画风'),
      TagLibraryCategory.create(name: '角色'),
      TagLibraryCategory.create(name: '构图'),
    ];
    final entries = [
      for (final category in categories)
        FixedTagEntry.create(
          name: category.name,
          content: 'tag ${category.name}',
          categoryId: category.id,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: entries,
      categories: categories,
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wrappedChip = find.text('角色 1');
    expect(wrappedChip, findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('已启用 4')).dy;
    final wrappedTop = tester.getTopLeft(wrappedChip).dy;

    expect(wrappedTop, greaterThan(firstTop + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FixedTagsButton long press toggles sidebar and tap keeps it open',
      (tester) async {
    final storage = _SidebarTestStorage(
      fixedEntries: const [],
      categories: const [],
      libraryEntries: const [],
    )..fixedSidebarExpanded = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: FixedTagsButton()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsButton)),
    );
    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isFalse,
    );

    await tester.longPress(find.byType(FixedTagsButton));
    await tester.pumpAndSettle();

    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isTrue,
    );
    expect(storage.fixedSidebarExpanded, isTrue);

    await tester.tap(find.byType(FixedTagsButton));
    await tester.pumpAndSettle();

    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isTrue,
    );
    expect(storage.fixedSidebarExpanded, isTrue);

    await tester.longPress(find.byType(FixedTagsButton));
    await tester.pumpAndSettle();

    expect(
      container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
      isFalse,
    );
    expect(storage.fixedSidebarExpanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GenerationScreen shows sidebar in narrow layout when expanded',
      (tester) async {
    final storage = _SidebarTestStorage(
      fixedEntries: const [],
      categories: const [],
      libraryEntries: const [],
    )..fixedSidebarExpanded = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 700,
              child: GenerationScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FixedTagsSidebar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list mode reorders from tile body without default drag handles',
      (tester) async {
    final first = FixedTagEntry.create(name: 'first', content: 'one');
    final second = FixedTagEntry.create(name: 'second', content: 'two');
    final storage = _SidebarTestStorage(
      fixedEntries: [first, second],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_handle), findsNothing);

    final firstTileText = find.descendant(
      of: find.byType(SidebarEntryTile),
      matching: find.text('first'),
    );
    final secondTileText = find.descendant(
      of: find.byType(SidebarEntryTile),
      matching: find.text('second'),
    );
    final start = tester.getCenter(firstTileText);
    final end = tester.getCenter(secondTileText);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(start);
    await tester.pump();
    await gesture.moveBy(end - start + const Offset(0, 64));
    await gesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsSidebar)),
    );
    expect(
      container
          .read(fixedTagsNotifierProvider)
          .positiveEntries
          .map((entry) => entry.id),
      [second.id, first.id],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dropping a positive link anchor on a negative tile creates a link',
      (tester) async {
    final positive = FixedTagEntry.create(
      name: 'artist',
      content: 'artist:fuzichoco',
      enabled: true,
    );
    final negative = FixedTagEntry.create(
      name: 'negative',
      content: 'bad hands',
      promptType: FixedTagPromptType.negative,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [positive, negative],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final linkIcons = find.byIcon(Icons.link_rounded);
    expect(linkIcons, findsNWidgets(2));

    final start = tester.getCenter(linkIcons.first);
    final negativeTile = find.ancestor(
      of: find.text('negative'),
      matching: find.byType(SidebarEntryTile),
    );
    final end = tester.getCenter(negativeTile);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsSidebar)),
    );
    expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));
    expect(storage.linksJson, isNot('[]'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dropping an existing link pair again removes the link',
      (tester) async {
    final positive = FixedTagEntry.create(
      name: 'artist',
      content: 'artist:fuzichoco',
      enabled: true,
    );
    final negative = FixedTagEntry.create(
      name: 'negative',
      content: 'bad hands',
      promptType: FixedTagPromptType.negative,
    );
    final existingLink = FixedTagLink.create(
      positiveEntryId: positive.id,
      negativeEntryId: negative.id,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [positive, negative],
      categories: const [],
      libraryEntries: const [],
    )..linksJson = jsonEncode([existingLink.toJson()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsSidebar)),
    );
    expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

    final start = tester.getCenter(find.byIcon(Icons.link_rounded).first);
    final negativeTile = find.ancestor(
      of: find.text('negative'),
      matching: find.byType(SidebarEntryTile),
    );
    final end = tester.getCenter(negativeTile);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(container.read(fixedTagsNotifierProvider).links, isEmpty);
    expect(storage.linksJson, '[]');
    expect(tester.takeException(), isNull);
  });

  for (final viewMode in ['list', 'grid']) {
    testWidgets('link drag preview follows the cursor in $viewMode mode',
        (tester) async {
      final positive = FixedTagEntry.create(
        name: 'artist',
        content: 'artist:fuzichoco',
        enabled: true,
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [positive, negative],
        categories: const [],
        libraryEntries: const [],
      )..fixedSidebarViewMode = viewMode;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.byIcon(Icons.link_rounded).first);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(58, 36));
      await tester.pump();

      expect(_linkPainterHasPreview(tester), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'dragging an existing link endpoint away removes the link in $viewMode mode',
        (tester) async {
      final positive = FixedTagEntry.create(
        name: 'artist',
        content: 'artist:fuzichoco',
        enabled: true,
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
      );
      final existingLink = FixedTagLink.create(
        positiveEntryId: positive.id,
        negativeEntryId: negative.id,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [positive, negative],
        categories: const [],
        libraryEntries: const [],
      )
        ..fixedSidebarViewMode = viewMode
        ..linksJson = jsonEncode([existingLink.toJson()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsSidebar)),
      );
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

      final endpoint = find.byIcon(Icons.link_rounded).last;
      final endpointCenter = tester.getCenter(endpoint);
      await tester.dragFrom(endpointCenter, const Offset(12, 0));
      await tester.pumpAndSettle();
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

      await tester.dragFrom(endpointCenter, const Offset(72, 0));
      await tester.pumpAndSettle();

      expect(container.read(fixedTagsNotifierProvider).links, isEmpty);
      expect(storage.linksJson, '[]');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('grid mode renders three tiles per row with library thumbnails',
      (tester) async {
    final libraryEntries = [
      TagLibraryEntry.create(
        name: 'thumb one',
        content: 'one',
        thumbnail: 'missing-one.png',
      ),
      TagLibraryEntry.create(
        name: 'thumb two',
        content: 'two',
        thumbnail: 'missing-two.png',
      ),
      TagLibraryEntry.create(
        name: 'thumb three',
        content: 'three',
        thumbnail: 'missing-three.png',
      ),
    ];
    final fixedEntries = [
      for (final entry in libraryEntries)
        FixedTagEntry.create(
          name: entry.name,
          content: entry.content,
          sourceEntryId: entry.id,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: fixedEntries,
      categories: const [],
      libraryEntries: libraryEntries,
    )..fixedSidebarViewMode = 'grid';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ThumbnailDisplay), findsNWidgets(3));

    final tiles = find.byType(SidebarEntryTile);
    expect(tiles, findsNWidgets(3));
    final firstTop = tester.getTopLeft(tiles.at(0)).dy;
    expect(tester.getTopLeft(tiles.at(1)).dy, closeTo(firstTop, 1));
    expect(tester.getTopLeft(tiles.at(2)).dy, closeTo(firstTop, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'positive list keeps exact scroll metrics across uneven sections and search changes',
    (tester) async {
      final fixture = _buildUnevenPositiveFixture();
      final storage = _SidebarTestStorage(
        fixedEntries: fixture.entries,
        categories: fixture.categories,
        libraryEntries: const [],
      );

      await _pumpSidebar(tester, storage, textScale: 1.35);

      final positiveScrollView = find.byType(CustomScrollView);
      final controller =
          tester.widget<CustomScrollView>(positiveScrollView).controller!;
      final initialMax = await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );

      controller.jumpTo(0);
      await tester.enterText(find.byType(TextField), 'section-3-');
      await tester.pumpAndSettle();

      final filteredMax = controller.position.maxScrollExtent;
      expect(filteredMax, greaterThan(0));
      expect(filteredMax, lessThan(initialMax));
      await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'positive grid keeps exact scroll metrics across uneven sections',
    (tester) async {
      final fixture = _buildUnevenPositiveFixture();
      final storage = _SidebarTestStorage(
        fixedEntries: fixture.entries,
        categories: fixture.categories,
        libraryEntries: const [],
      )..fixedSidebarViewMode = 'grid';

      await _pumpSidebar(tester, storage);

      final positiveScrollView = find.byType(CustomScrollView);
      final controller =
          tester.widget<CustomScrollView>(positiveScrollView).controller!;
      await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative list keeps exact scroll metrics while scrolling', (
    tester,
  ) async {
    final entries = [
      for (var index = 0; index < 32; index++)
        FixedTagEntry.create(
          name: 'negative-$index',
          content: 'negative tag $index',
          enabled: false,
          promptType: FixedTagPromptType.negative,
          sortOrder: index,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: entries,
      categories: const [],
      libraryEntries: const [],
    );

    await _pumpSidebar(tester, storage, textScale: 1.35);

    final negativeList = find.byType(ReorderableListView);
    expect(negativeList, findsOneWidget);
    final controller =
        tester.widget<ReorderableListView>(negativeList).scrollController!;
    await _expectStableScrollMetrics(
      tester,
      controller: controller,
      scrollable: negativeList,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category chip scrolls to a section beyond the initial viewport',
    (tester) async {
      final near = TagLibraryCategory.create(name: 'Near', sortOrder: 0);
      final far = TagLibraryCategory.create(name: 'Far', sortOrder: 1);
      final entries = [
        for (var index = 0; index < 30; index++)
          FixedTagEntry.create(
            name: 'near-$index',
            content: 'near tag $index',
            enabled: false,
            categoryId: near.id,
            sortOrder: index,
          ),
        FixedTagEntry.create(
          name: 'far-entry',
          content: 'far tag',
          enabled: false,
          categoryId: far.id,
          sortOrder: 30,
        ),
      ];
      final storage = _SidebarTestStorage(
        fixedEntries: entries,
        categories: [near, far],
        libraryEntries: const [],
      );

      await _pumpSidebar(tester, storage);

      final positiveScrollView = find.byType(CustomScrollView);
      final controller =
          tester.widget<CustomScrollView>(positiveScrollView).controller!;
      final initialMax = controller.position.maxScrollExtent;

      await tester.tap(find.text('Far 1'));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(controller.position.maxScrollExtent, closeTo(initialMax, 0.01));
      expect(
        tester
            .getRect(positiveScrollView)
            .overlaps(tester.getRect(find.text('Far'))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SidebarEntryTile triggers edit action after hover',
      (tester) async {
    var edited = false;
    final entry = FixedTagEntry.create(name: 'tile', content: 'tag');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SidebarEntryTile(
                entry: entry,
                categoryColor: Colors.blue,
                isListMode: true,
                onToggle: () {},
                onEdit: () => edited = true,
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SidebarEntryTile)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_rounded));

    expect(edited, isTrue);
  });
}

({List<TagLibraryCategory> categories, List<FixedTagEntry> entries})
    _buildUnevenPositiveFixture() {
  const counts = [1, 18, 3, 24];
  final categories = [
    for (var index = 0; index < counts.length; index++)
      TagLibraryCategory.create(name: 'Section $index', sortOrder: index),
  ];
  final entries = <FixedTagEntry>[
    for (var sectionIndex = 0; sectionIndex < categories.length; sectionIndex++)
      for (var entryIndex = 0; entryIndex < counts[sectionIndex]; entryIndex++)
        FixedTagEntry.create(
          name: 'section-$sectionIndex-entry-$entryIndex',
          content: 'tag section-$sectionIndex-$entryIndex',
          enabled: false,
          categoryId: categories[sectionIndex].id,
          sortOrder: entryIndex,
        ),
  ];
  return (categories: categories, entries: entries);
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  _SidebarTestStorage storage, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: const Scaffold(
          body: SizedBox(width: 340, height: 620, child: FixedTagsSidebar()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<double> _expectStableScrollMetrics(
  WidgetTester tester, {
  required ScrollController controller,
  required Finder scrollable,
}) async {
  expect(controller.hasClients, isTrue);
  controller.jumpTo(0);
  await tester.pump();

  final initialMax = controller.position.maxScrollExtent;
  final initialViewport = controller.position.viewportDimension;
  final initialVisibleFraction =
      initialViewport / (initialMax + initialViewport);
  expect(initialMax, greaterThan(0));

  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(scrollable),
      scrollDelta: const Offset(0, 120),
    ),
  );
  await tester.pump();

  expect(controller.offset, greaterThan(0));
  _expectScrollMetrics(
    controller,
    maxScrollExtent: initialMax,
    viewportDimension: initialViewport,
    visibleFraction: initialVisibleFraction,
  );

  controller.jumpTo(0);
  await tester.pump();
  var previousOffset = controller.offset;
  for (final fraction in const [0.2, 0.5, 0.8, 0.98]) {
    final target = initialMax * fraction;
    controller.jumpTo(target);
    await tester.pump();

    expect(controller.offset, greaterThan(previousOffset));
    expect(controller.offset, closeTo(target, 0.01));
    _expectScrollMetrics(
      controller,
      maxScrollExtent: initialMax,
      viewportDimension: initialViewport,
      visibleFraction: initialVisibleFraction,
    );
    previousOffset = controller.offset;
  }

  return initialMax;
}

void _expectScrollMetrics(
  ScrollController controller, {
  required double maxScrollExtent,
  required double viewportDimension,
  required double visibleFraction,
}) {
  final position = controller.position;
  expect(position.maxScrollExtent, closeTo(maxScrollExtent, 0.01));
  expect(position.viewportDimension, closeTo(viewportDimension, 0.01));
  expect(
    position.viewportDimension /
        (position.maxScrollExtent + position.viewportDimension),
    closeTo(visibleFraction, 0.0001),
  );
}

bool _linkPainterHasPreview(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  for (final customPaint in customPaints) {
    final painter = customPaint.painter;
    if (painter is! SidebarLinkPainter) continue;
    try {
      final dynamic linkPainter = painter;
      return linkPainter.previewStart != null && linkPainter.previewEnd != null;
    } catch (_) {
      return false;
    }
  }
  return false;
}

class _SidebarTestStorage extends LocalStorageService {
  _SidebarTestStorage({
    required this.fixedEntries,
    required this.categories,
    required this.libraryEntries,
  });

  final List<FixedTagEntry> fixedEntries;
  final List<TagLibraryCategory> categories;
  final List<TagLibraryEntry> libraryEntries;

  bool fixedSidebarExpanded = true;
  double fixedSidebarWidth = 320.0;
  String fixedSidebarViewMode = 'list';
  double negativeHeight = 180.0;
  String linksJson = '[]';

  @override
  bool getLeftPanelExpanded() => true;

  @override
  bool getRightPanelExpanded() => true;

  @override
  double getLeftPanelWidth() => 300.0;

  @override
  double getRightPanelWidth() => 280.0;

  @override
  double getPromptAreaHeight() => 200.0;

  @override
  bool getPromptMaximized() => false;

  @override
  bool getFixedTagsSidebarExpanded() => fixedSidebarExpanded;

  @override
  Future<void> setFixedTagsSidebarExpanded(bool expanded) async {
    fixedSidebarExpanded = expanded;
  }

  @override
  double getFixedTagsSidebarWidth() => fixedSidebarWidth;

  @override
  Future<void> setFixedTagsSidebarWidth(double width) async {
    fixedSidebarWidth = width;
  }

  @override
  String getFixedTagsSidebarViewMode() => fixedSidebarViewMode;

  @override
  Future<void> setFixedTagsSidebarViewMode(String mode) async {
    fixedSidebarViewMode = mode;
  }

  @override
  double getFixedTagsNegativeHeight() => negativeHeight;

  @override
  Future<void> setFixedTagsNegativeHeight(double height) async {
    negativeHeight = height;
  }

  @override
  String? getFixedTagsJson() {
    return jsonEncode(fixedEntries.map((entry) => entry.toJson()).toList());
  }

  @override
  Future<void> setFixedTagsJson(String json) async {}

  @override
  String? getFixedTagLinksJson() => linksJson;

  @override
  Future<void> setFixedTagLinksJson(String json) async {
    linksJson = json;
  }

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getTagLibraryEntriesJson() {
    return jsonEncode(libraryEntries.map((entry) => entry.toJson()).toList());
  }

  @override
  String? getTagLibraryCategoriesJson() {
    return jsonEncode(
      categories.map((category) => category.toJson()).toList(),
    );
  }

  @override
  int getTagLibraryViewMode() => 1;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String getLastPrompt() => '';

  @override
  String getLastNegativePrompt() => '';

  @override
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;
}
