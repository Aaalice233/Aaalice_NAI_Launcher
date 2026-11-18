import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_screen.dart';
import 'package:nai_launcher/presentation/widgets/common/pagination_bar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_state_views.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _Gallery extends Fake implements LocalGalleryService {
  final records = <LocalImageRecord>[];
  Completer<void>? readGate;

  @override
  FilterCriteria currentFilter = const FilterCriteria();

  Iterable<LocalImageRecord> get matches =>
      records.where((image) => image.path.contains(currentFilter.searchQuery));

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
  Future<int> getFavoriteCount() async => 0;
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

Future<ProviderContainer> _pumpGallery(
  WidgetTester tester,
  _Gallery service,
) async {
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
      galleryServiceProvider.overrideWith(
        () => GalleryService(createService: () => service),
      ),
      galleryCategoryNotifierProvider.overrideWithBuild(
        (_, _) => const GalleryCategoryState(),
      ),
      galleryAlbumNotifierProvider.overrideWithBuild(
        (_, _) => const GalleryAlbumState(),
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
