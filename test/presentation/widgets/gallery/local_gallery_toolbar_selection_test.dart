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

  testWidgets('remove-from-album action only appears while browsing an album', (
    tester,
  ) async {
    await _pumpToolbar(tester);
    expect(find.byIcon(Icons.playlist_remove), findsNothing);

    await _pumpToolbar(tester, onRemoveFromAlbum: _noop);

    // 宽度不足时批量动作只显示图标；显隐条件是本用例的验证边界，
    // 点击链路与其他批量按钮共用同一机制
    expect(find.byIcon(Icons.playlist_remove), findsOneWidget);
  });

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

  for (final width in [320.0, 360.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'mobile toolbar keeps search count and complete actions at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 500));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpToolbar(tester, selectionActive: false);

        final compact = width < 1180;
        expect(
          find.byKey(
            ValueKey(
              compact
                  ? 'localGalleryMobileActionBar'
                  : 'localGalleryDesktopToolbar',
            ),
          ),
          findsOneWidget,
        );

        if (compact) {
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
            tester
                .getRect(searchSurface)
                .contains(tester.getCenter(resultCount)),
            isTrue,
          );
        }

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

  for (final width in [320.0, 360.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'toolbar preserves every compact action at 3x text and ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpToolbar(tester, selectionActive: false, textScaleFactor: 3);

        expect(
          find.byKey(const ValueKey('localGalleryCompactToolbar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('localGalleryMobileActionBar')),
          findsOneWidget,
        );
        for (final label in ['分类', '筛选', '日期', '多选', '刷新']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 360.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'batch toolbar remains operable at 3x text and ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpToolbar(tester, textScaleFactor: 3);

        expect(find.byIcon(Icons.close), findsOneWidget);
        if (width < 700) {
          expect(find.byIcon(Icons.library_add_check_outlined), findsOneWidget);
          expect(find.byIcon(Icons.more_vert), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.check_box_outlined), findsWidgets);
          expect(find.byIcon(Icons.done_all), findsOneWidget);
          expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
          expect(find.byIcon(Icons.delete_outline), findsOneWidget);
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
  VoidCallback? onRemoveFromAlbum,
  double textScaleFactor = 1,
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
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
            child: Scaffold(
              body: LocalGalleryToolbar(
                enableSearchAutocomplete: false,
                onToggleCategoryPanel: _noop,
                onRemoveFromAlbum: onRemoveFromAlbum,
              ),
            ),
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
