import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_entry_tile.dart';

const _bulkEntryCount = 200;
const _mountedTileBudget = 24;

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_lazy_hive_');
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

  testWidgets('list mode builds a bounded slice and still reaches the last '
      'entry', (tester) async {
    final fixture = _bulkFixture();
    await _pumpSidebar(tester, _LazyLayoutStorage(fixture: fixture));

    final mounted = find.byType(SidebarEntryTile).evaluate().length;
    expect(mounted, greaterThan(0));
    expect(mounted, lessThan(_mountedTileBudget));
    _expectBuiltTilesCoverViewport(tester);

    final controller = _positiveController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.text(fixture.entries.last.name), findsOneWidget);
    expect(
      find.byType(SidebarEntryTile).evaluate().length,
      lessThan(_mountedTileBudget),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid mode builds a bounded slice and still reaches the last '
      'entry', (tester) async {
    final fixture = _bulkFixture();
    await _pumpSidebar(
      tester,
      _LazyLayoutStorage(fixture: fixture, viewMode: 'grid'),
    );

    final mounted = find.byType(SidebarEntryTile).evaluate().length;
    expect(mounted, greaterThan(0));
    expect(mounted, lessThan(_mountedTileBudget));
    _expectBuiltTilesCoverViewport(tester);

    final controller = _positiveController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.text(fixture.entries.last.name), findsOneWidget);
    expect(
      find.byType(SidebarEntryTile).evaluate().length,
      lessThan(_mountedTileBudget),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing a folder shrinks the scroll range', (tester) async {
    final fixture = _bulkFixture();
    await _pumpSidebar(tester, _LazyLayoutStorage(fixture: fixture));

    final controller = _positiveController(tester);
    final expandedExtent = controller.position.maxScrollExtent;
    expect(expandedExtent, greaterThan(0));

    final bodyKey = ValueKey(
      'fixed-tags-positive-group-${fixture.category.id}-body',
    );
    expect(find.byKey(bodyKey), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('fixed-tags-positive-group-${fixture.category.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(bodyKey), findsNothing);
    expect(find.byType(SidebarEntryTile), findsNothing);
    expect(controller.position.maxScrollExtent, lessThan(expandedExtent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reordering keeps the scroll offset stable', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    final fixture = _bulkFixture();
    await _pumpSidebar(tester, _LazyLayoutStorage(fixture: fixture));

    final controller = _positiveController(tester);
    final maximumExtent = controller.position.maxScrollExtent;
    controller.jumpTo(maximumExtent / 2);
    await tester.pumpAndSettle();
    final offsetBeforeDrag = controller.offset;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsSidebar)),
    );
    List<String> currentOrder() => container
        .read(fixedTagsNotifierProvider)
        .positiveEntries
        .map((entry) => entry.id)
        .toList();

    // 缓存区里的条目已经建好但在视口外，拿它当拖拽起点点不中。
    final dragged = _tileWithRoomBelow(tester);
    final draggedRect = tester.getRect(find.byWidget(dragged));
    final indexBeforeDrag = currentOrder().indexOf(dragged.entry.id);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.text(dragged.entry.name)));
    await tester.pump();
    // 一次性大跨度 move 只够让识别器进竞技场，分步移动才会走到插入位判定。
    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(Offset(0, draggedRect.height * 0.25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      currentOrder().indexOf(dragged.entry.id),
      greaterThan(indexBeforeDrag),
    );
    expect(controller.offset, closeTo(offsetBeforeDrag, 0.01));
    expect(controller.position.maxScrollExtent, closeTo(maximumExtent, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final width in const [320.0, 600.0, 840.0]) {
    for (final viewMode in const ['list', 'grid']) {
      for (final textScale in const [1.0, 3.0]) {
        testWidgets(
          '$viewMode mode at $width with ${textScale}x text avoids overflow',
          (tester) async {
            final fixture = _bulkFixture(entryCount: 12);
            await _pumpSidebar(
              tester,
              _LazyLayoutStorage(fixture: fixture, viewMode: viewMode),
              width: width,
              // 3 倍文字下顶栏与面板头会吃掉大部分高度，视口要够高才测得到宽度维度。
              height: textScale > 1 ? 1400 : 620,
              textScale: textScale,
            );

            expect(find.byType(SidebarEntryTile), findsWidgets);
            expect(tester.takeException(), isNull);

            final controller = _positiveController(tester);
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pumpAndSettle();

            expect(find.text(fixture.entries.last.name), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

void _expectBuiltTilesCoverViewport(WidgetTester tester) {
  final viewport = tester.getRect(
    find.byKey(const ValueKey('fixed-tags-positive-group-list')),
  );
  final bottoms = tester
      .widgetList<SidebarEntryTile>(find.byType(SidebarEntryTile))
      .map((tile) => tester.getRect(find.byWidget(tile)).bottom);
  expect(bottoms.reduce(math.max), greaterThanOrEqualTo(viewport.bottom));
}

SidebarEntryTile _tileWithRoomBelow(WidgetTester tester) {
  final viewport = tester.getRect(
    find.byKey(const ValueKey('fixed-tags-positive-group-list')),
  );
  for (final tile in tester.widgetList<SidebarEntryTile>(
    find.byType(SidebarEntryTile),
  )) {
    final rect = tester.getRect(find.byWidget(tile));
    if (rect.top >= viewport.top &&
        rect.bottom + rect.height * 1.5 <= viewport.bottom) {
      return tile;
    }
  }
  fail('no fully visible entry tile with room below it');
}

ScrollController _positiveController(WidgetTester tester) {
  return tester
      .widget<CustomScrollView>(
        find.byKey(const ValueKey('fixed-tags-positive-group-list')),
      )
      .controller!;
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  _LazyLayoutStorage storage, {
  double width = 340,
  double height = 620,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: const FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

_BulkFixture _bulkFixture({int entryCount = _bulkEntryCount}) {
  final category = TagLibraryCategory.create(name: 'Bulk', sortOrder: 0);
  return _BulkFixture(
    category: category,
    entries: [
      for (var index = 0; index < entryCount; index++)
        FixedTagEntry.create(
          name: 'bulk-${index.toString().padLeft(3, '0')}',
          content: 'bulk tag $index',
          enabled: false,
          categoryId: category.id,
          sortOrder: index,
        ),
    ],
  );
}

class _BulkFixture {
  const _BulkFixture({required this.category, required this.entries});

  final TagLibraryCategory category;
  final List<FixedTagEntry> entries;
}

class _LazyLayoutStorage extends LocalStorageService {
  _LazyLayoutStorage({required this.fixture, String viewMode = 'list'})
    : _viewMode = viewMode;

  final _BulkFixture fixture;

  String _viewMode;
  String _linksJson = '[]';
  double _negativeHeight = 180.0;

  @override
  bool getFixedTagsSidebarExpanded() => true;

  @override
  double getFixedTagsSidebarWidth() => 320.0;

  @override
  String getFixedTagsSidebarViewMode() => _viewMode;

  @override
  Future<void> setFixedTagsSidebarViewMode(String mode) async {
    _viewMode = mode;
  }

  @override
  double getFixedTagsNegativeHeight() => _negativeHeight;

  @override
  Future<void> setFixedTagsNegativeHeight(double height) async {
    _negativeHeight = height;
  }

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getFixedTagsJson() {
    return jsonEncode(fixture.entries.map((entry) => entry.toJson()).toList());
  }

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
  String? getTagLibraryCategoriesJson() {
    return jsonEncode([fixture.category.toJson()]);
  }

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getHighlightEmphasis() => false;
}
