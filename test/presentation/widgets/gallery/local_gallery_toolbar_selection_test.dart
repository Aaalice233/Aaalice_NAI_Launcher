import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_gallery_toolbar.dart';

void _noop() {}

void main() {
  late Directory hiveDir;

  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('local_toolbar_hive_');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'selection toolbar separates current page and all result actions',
    (tester) async {
      await _pumpToolbar(tester);

      expect(find.byTooltip('选择本页'), findsOneWidget);
      expect(find.byTooltip('选择全部'), findsOneWidget);
      expect(find.byTooltip('全选'), findsNothing);
    },
  );

  testWidgets('select current page only selects visible page paths', (
    tester,
  ) async {
    final container = await _pumpToolbar(tester);

    await tester.tap(find.byTooltip('选择本页'));
    await tester.pump();

    expect(container.read(localGallerySelectionNotifierProvider).selectedIds, {
      r'C:\gallery\page-1.png',
      r'C:\gallery\page-2.png',
    });
    expect(find.byTooltip('取消本页'), findsOneWidget);
    expect(find.byTooltip('选择全部'), findsOneWidget);
  });

  testWidgets('normal toolbar wraps actions without overflow at narrow width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpToolbar(tester, selectionActive: false);

    expect(find.byType(LocalGalleryToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets(
      'mobile toolbar keeps search count and complete actions at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 500));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpToolbar(tester, selectionActive: false);

        expect(
          find.byKey(const ValueKey('localGalleryMobileSearchRow')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('localGalleryMobileActionBar')),
          findsOneWidget,
        );

        final resultCount = find.byKey(
          const ValueKey('localGalleryMobileSearchResultCount'),
        );
        final searchSurface = find.ancestor(
          of: resultCount,
          matching: find.byType(InputSurfaceContainer),
        );
        expect(resultCount, findsOneWidget);
        expect(searchSurface, findsOneWidget);
        expect(
          tester.getRect(searchSurface).contains(tester.getCenter(resultCount)),
          isTrue,
        );

        for (final label in ['分类', '筛选', '日期', '多选', '刷新']) {
          final labelFinder = find.text(label);
          expect(labelFinder, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(labelFinder).didExceedMaxLines,
            isFalse,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('select all replaces selection with all filtered result paths', (
    tester,
  ) async {
    final container = await _pumpToolbar(
      tester,
      initialSelectedIds: {r'C:\gallery\stale.png'},
    );

    await tester.tap(find.byTooltip('选择全部'));
    await tester.pumpAndSettle();

    expect(container.read(localGallerySelectionNotifierProvider).selectedIds, {
      r'C:\gallery\page-1.png',
      r'C:\gallery\page-2.png',
      r'C:\gallery\result-3.png',
      r'C:\gallery\result-4.png',
      r'C:\gallery\result-5.png',
    });
    expect(find.byTooltip('取消全部'), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpToolbar(
  WidgetTester tester, {
  Set<String> initialSelectedIds = const {},
  bool selectionActive = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localGalleryNotifierProvider.overrideWith(
          () => _ToolbarGalleryNotifier(
            LocalGalleryState(
              currentImages: [
                _record(r'C:\gallery\page-1.png'),
                _record(r'C:\gallery\page-2.png'),
              ],
              filteredCount: 5,
              totalCount: 5,
              totalPages: 3,
              isInitialized: true,
            ),
            filteredPaths: const [
              r'C:\gallery\page-1.png',
              r'C:\gallery\page-2.png',
              r'C:\gallery\result-3.png',
              r'C:\gallery\result-4.png',
              r'C:\gallery\result-5.png',
            ],
          ),
        ),
        localGallerySelectionNotifierProvider.overrideWith(
          () => _ActiveSelectionNotifier(
            initialSelectedIds,
            isActive: selectionActive,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocalGalleryToolbar(
            enableSearchAutocomplete: false,
            onToggleCategoryPanel: _noop,
          ),
        ),
      ),
    ),
  );

  return ProviderScope.containerOf(
    tester.element(find.byType(LocalGalleryToolbar)),
  );
}

LocalImageRecord _record(String path) {
  return LocalImageRecord(path: path, size: 1, modifiedAt: DateTime(2026));
}

class _ToolbarGalleryNotifier extends LocalGalleryNotifier {
  _ToolbarGalleryNotifier(this._initialState, {required this.filteredPaths});

  final LocalGalleryState _initialState;
  final List<String> filteredPaths;

  @override
  LocalGalleryState build() => _initialState;

  @override
  Future<List<String>> getFilteredImagePaths() async => filteredPaths;
}

class _ActiveSelectionNotifier extends LocalGallerySelectionNotifier {
  _ActiveSelectionNotifier(this._initialSelectedIds, {required this.isActive});

  final Set<String> _initialSelectedIds;
  final bool isActive;

  @override
  SelectionModeState build() {
    return SelectionModeState(
      isActive: isActive,
      selectedIds: _initialSelectedIds,
    );
  }
}
