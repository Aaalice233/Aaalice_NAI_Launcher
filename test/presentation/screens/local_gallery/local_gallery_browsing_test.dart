import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_scan_progress_provider.dart';
import '../../../helpers/gallery_folder_notifications.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_screen.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_category_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/pagination_bar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_state_views.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _Gallery extends Fake implements LocalGalleryService {
  final records = <LocalImageRecord>[];
  Completer<void>? readGate;
  final refreshes = <bool>[];
  @override
  Future<void> refresh({bool scan = true}) async => refreshes.add(scan);

  @override
  FilterCriteria currentFilter = const FilterCriteria();

  Iterable<LocalImageRecord> get matches => records.where((image) {
    final filter = currentFilter;
    return image.path.contains(filter.searchQuery) &&
        (filter.categoryFolderPath == null ||
            image.path.startsWith('${filter.categoryFolderPath}/')) &&
        (filter.albumId == null || image.path.endsWith('album.png')) &&
        (!filter.showFavoritesOnly || image.path.endsWith('star.png'));
  });

  @override
  Future<List<File>> initialize() async =>
      records.map((r) => File(r.path)).toList();
  @override
  bool get isInitialized => true;
  @override
  int get totalCount => records.length;
  @override
  int get filteredCount => matches.length;
  @override
  Future<int> getFavoriteCount() async =>
      records.where((r) => r.path.endsWith('star.png')).length;
  @override
  Future<void> applyFilter(FilterCriteria criteria) async =>
      currentFilter = criteria;
  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    await readGate?.future;
    return matches.skip(page * pageSize!).take(pageSize).toList();
  }

  @override
  Future<GalleryIndexAdmission> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) async {
    records.add(_record(filePath));
    return GalleryIndexAdmission.added;
  }

  @override
  Future<void> dispose() async {}
}

LocalImageRecord _record(String path) =>
    LocalImageRecord(path: path, modifiedAt: DateTime(2026, 11, 18), size: 1);

class _Scan extends GalleryScanProgressNotifier {
  _Scan(this.scanning);
  final bool scanning;
  @override
  ScanProgressState build() => ScanProgressState(isScanning: scanning);
  void finish() => state = const ScanProgressState();
}

Future<ProviderContainer> _pumpGallery(
  WidgetTester tester,
  _Gallery service, {
  bool scanning = false,
}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.hasSeenLocalGalleryTip: true,
  });
  final visibility = VisibilityDetectorController.instance;
  final interval = visibility.updateInterval;
  visibility.updateInterval = Duration.zero;
  addTearDown(() => visibility.updateInterval = interval);
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/local-gallery',
    routes: [
      GoRoute(
        path: '/local-gallery',
        builder: (_, _) => const LocalGalleryScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      galleryScanProgressProvider.overrideWith(() => _Scan(scanning)),
      autocompleteSettingsProvider.overrideWithBuild(
        (_, _) => const AutocompleteSettings(
          enabled: false,
          zhInstallPromptDismissed: true,
        ),
      ),
      galleryServiceProvider.overrideWith(
        () => GalleryService(createService: () => service),
      ),
      galleryCategoryNotifierProvider.overrideWith(
        () => RecordingGalleryFolders(
          GalleryCategoryState(
            categories: [
              GalleryCategory(
                id: 'folder',
                name: 'Folder',
                folderPath: 'folder',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ],
          ),
        ),
      ),
      galleryAlbumNotifierProvider.overrideWithBuild(
        (_, _) => GalleryAlbumState(
          albums: [
            GalleryAlbum(
              id: 'album',
              name: 'Album',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

void main() {
  testWidgets('扫描结束后补做一次侧栏同步，工具栏与刷新快捷键均同步', (tester) async {
    final service = _Gallery();
    final container = await _pumpGallery(tester, service, scanning: true);
    final folders =
        container.read(galleryCategoryNotifierProvider.notifier)
            as RecordingGalleryFolders;
    await tester.pump(const Duration(seconds: 1));
    expect(folders.syncs, 0);
    (container.read(galleryScanProgressProvider.notifier) as _Scan).finish();
    await tester.pump();
    expect(service.refreshes, [false]);
    expect(folders.syncs, 1);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('local-gallery-toolbar')),
        matching: find.byIcon(Icons.refresh),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
    expect(service.refreshes, [false, true, true]);
    expect(folders.syncs, 3);
  });
  for (final scope in ['folder', 'album', 'favorites']) {
    testWidgets('$scope 范围通过工具栏、快捷键和无结果页清除条件后保留', (tester) async {
      final service = _Gallery()
        ..records.addAll([
          _record('folder/entry.png'),
          _record('other/album.png'),
          _record('other/star.png'),
        ]);
      final container = await _pumpGallery(tester, service);
      LocalGalleryCategoryPanel panel() =>
          tester.widget(find.byType(LocalGalleryCategoryPanel));
      if (scope == 'folder') {
        panel().onCategorySelected(scope);
      } else {
        panel().onAlbumSelected(scope);
      }
      await tester.pump();
      final expected = {
        'folder': 'folder/entry.png',
        'album': 'other/album.png',
        'favorites': 'other/star.png',
      }[scope];
      void checkScope() {
        expect(
          panel().categoryState.selectedCategoryId,
          scope == 'folder' ? scope : null,
        );
        expect(
          panel().albumState.selectedAlbumId,
          scope == 'folder' ? null : scope,
        );
        expect(find.text('1/3'), findsOneWidget);
        expect(find.byIcon(Icons.filter_alt_off), findsNothing);
        expect(
          tester
              .widget<LocalImageCard3D>(find.byType(LocalImageCard3D))
              .record
              .path,
          expected,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
      }

      checkScope();
      final gallery = container.read(localGalleryNotifierProvider.notifier);
      for (final entry in ['toolbar', 'shortcut', 'empty']) {
        await gallery.setSearchQuery('unmatched');
        await tester.pump();
        expect(find.text('0/3'), findsOneWidget);
        switch (entry) {
          case 'toolbar':
            await tester.tap(
              find.descendant(
                of: find.byKey(const Key('local-gallery-toolbar')),
                matching: find.byIcon(Icons.filter_alt_off),
              ),
            );
          case 'shortcut':
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          case 'empty':
            await tester.tap(
              find.descendant(
                of: find.byType(GalleryNoResultsView),
                matching: find.text('清除筛选'),
              ),
            );
        }
        await tester.pump();
        checkScope();
      }
      await tester.enterText(find.byType(EditableText), 'pending');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.filter_alt_off));
      await tester.pump(const Duration(milliseconds: 301));
      checkScope();
    });
  }
  testWidgets('只有浏览范围时空态无清除按钮', (tester) async {
    await _pumpGallery(tester, _Gallery());
    tester
        .widget<LocalGalleryCategoryPanel>(
          find.byType(LocalGalleryCategoryPanel),
        )
        .onCategorySelected('folder');
    await tester.pump();
    expect(find.text('这里还没有图片'), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_off), findsNothing);
    expect(find.byType(GalleryNoResultsView), findsNothing);
  });
  testWidgets('网格零结果后切换日期分组并清除条件可见卡片', (tester) async {
    final service = _Gallery()..records.add(_record('one.png'));
    final container = await _pumpGallery(tester, service);
    final gallery = container.read(localGalleryNotifierProvider.notifier);
    expect(find.byType(PaginationBar), findsOneWidget);
    await gallery.setGroupedView(true);
    await tester.pump();
    expect(find.byType(PaginationBar), findsNothing);
    await gallery.setGroupedView(false);
    await gallery.setSearchQuery('missing');
    await tester.pump();
    expect(find.byType(GalleryNoResultsView), findsOneWidget);
    await gallery.setGroupedView(true);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(GalleryNoResultsView),
        matching: find.text('清除筛选'),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<LocalImageCard3D>(find.byType(LocalImageCard3D))
          .record
          .path,
      'one.png',
    );
    expect(find.byType(PaginationBar), findsNothing);
  });

  testWidgets('空分组的加载态及第一张新图出现在页面上', (tester) async {
    final service = _Gallery();
    final container = await _pumpGallery(tester, service);
    final gallery = container.read(localGalleryNotifierProvider.notifier);
    service.readGate = Completer<void>();
    final loading = gallery.setGroupedView(true);
    await tester.pump();
    expect(find.byType(GalleryLoadingView), findsOneWidget);
    service.readGate!.complete();
    await loading;
    await tester.pump();
    expect(find.byType(GalleryEmptyView), findsOneWidget);
    await gallery.addNewlySavedImages(['first.png']);
    await tester.pump();
    expect(
      tester
          .widget<LocalImageCard3D>(find.byType(LocalImageCard3D))
          .record
          .path,
      'first.png',
    );
    expect(find.byType(PaginationBar), findsNothing);
  });
}
