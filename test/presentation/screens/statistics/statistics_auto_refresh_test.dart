import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/core/database/database_manager.dart';
import 'package:nai_launcher/core/database/database_providers.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/gallery_dashboard_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/services/statistics_cache_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_state.dart';
import 'package:nai_launcher/presentation/widgets/app_branch_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDatabaseManager extends Mock implements DatabaseManager {}

class _MockGalleryDataSource extends Mock implements GalleryDataSource {}

class _MockStatisticsCacheService extends Mock
    implements StatisticsCacheService {}

void main() {
  final cacheManager = GalleryCacheManager();
  late ProviderContainer container;
  late int queries;
  late int totalImages;
  Completer<GalleryDashboardSnapshot>? heldQuery;

  setUpAll(() {
    registerFallbackValue(
      GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0,
        calculatedAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    queries = 0;
    totalImages = 1234;
    heldQuery = null;

    final dataSource = _MockGalleryDataSource();
    when(() => dataSource.countImages()).thenAnswer((_) async => totalImages);
    when(dataSource.getDashboardStatistics).thenAnswer((_) {
      queries++;
      final held = heldQuery;
      heldQuery = null;
      return held?.future ?? Future.value(_snapshot(totalImages));
    });
    final databaseManager = _MockDatabaseManager();
    when(
      () => databaseManager.getDataSource<GalleryDataSource>('gallery'),
    ).thenReturn(dataSource);
    final statisticsCache = _MockStatisticsCacheService();
    when(statisticsCache.getCache).thenReturn(null);
    when(() => statisticsCache.isCacheValid(any())).thenReturn(false);
    when(
      () => statisticsCache.saveCache(any(), any()),
    ).thenAnswer((_) async {});
    when(statisticsCache.clearCache).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        databaseManagerProvider.overrideWith((ref) async => databaseManager),
        statisticsCacheServiceProvider.overrideWithValue(statisticsCache),
      ],
    );
    addTearDown(container.dispose);
  });

  testWidgets('gallery writes refresh the open page once per burst', (
    tester,
  ) async {
    await _show(tester, container, visible: true);
    expect(queries, 1);
    expect(find.text('1234'), findsOneWidget);

    totalImages = 5678;
    for (var write = 0; write < 3; write++) {
      cacheManager.invalidateStatistics();
      await tester.pump(StatisticsNotifier.galleryChangeDebounce ~/ 2);
    }
    expect(queries, 1, reason: 'writes keep postponing the reload');

    await tester.pump(StatisticsNotifier.galleryChangeDebounce);
    await tester.pumpAndSettle();
    expect(queries, 2);
    expect(find.text('5678'), findsOneWidget);
  });

  testWidgets('a write landing mid-query leads to exactly one more reload', (
    tester,
  ) async {
    await _show(tester, container, visible: true);
    final slowQuery = Completer<GalleryDashboardSnapshot>();
    heldQuery = slowQuery;

    unawaited(container.read(statisticsNotifierProvider.notifier).refresh());
    await tester.pump();
    expect(queries, 2);

    totalImages = 42;
    cacheManager.invalidateStatistics();
    slowQuery.complete(_snapshot(1234));
    await tester.pump();
    expect(find.text('1234'), findsOneWidget);

    await tester.pump(StatisticsNotifier.galleryChangeDebounce);
    await tester.pumpAndSettle();
    expect(queries, 3);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('a reload due while a query runs waits for it, then reloads', (
    tester,
  ) async {
    await _show(tester, container, visible: true);
    final slowQuery = Completer<GalleryDashboardSnapshot>();
    heldQuery = slowQuery;

    unawaited(container.read(statisticsNotifierProvider.notifier).refresh());
    await tester.pump();
    totalImages = 42;
    cacheManager.invalidateStatistics();
    await tester.pump(StatisticsNotifier.galleryChangeDebounce * 2);
    expect(queries, 2, reason: 'the due reload waits for the running query');

    slowQuery.complete(_snapshot(1234));
    await tester.pumpAndSettle();
    expect(queries, 3);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('hiding the page while a due reload waits cancels that reload', (
    tester,
  ) async {
    await _show(tester, container, visible: true);
    final slowQuery = Completer<GalleryDashboardSnapshot>();
    heldQuery = slowQuery;

    unawaited(container.read(statisticsNotifierProvider.notifier).refresh());
    await tester.pump();
    totalImages = 42;
    cacheManager.invalidateStatistics();
    await tester.pump(StatisticsNotifier.galleryChangeDebounce * 2);
    await _show(tester, container, visible: false);
    slowQuery.complete(_snapshot(1234));
    await tester.pumpAndSettle();
    expect(queries, 2, reason: 'no reload once the page is hidden');

    await _show(tester, container, visible: true);
    expect(queries, 3);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('a hidden page neither reloads nor misses the change', (
    tester,
  ) async {
    await _show(tester, container, visible: true);
    expect(queries, 1);

    totalImages = 5678;
    cacheManager.invalidateStatistics();
    await _show(tester, container, visible: false);
    await tester.pump(StatisticsNotifier.galleryChangeDebounce * 2);
    cacheManager.invalidateStatistics();
    await tester.pump(StatisticsNotifier.galleryChangeDebounce * 2);

    expect(queries, 1, reason: 'no reload while the page is hidden');
    expect(
      container.read(statisticsNotifierProvider).statistics!.totalImages,
      1234,
    );

    await _show(tester, container, visible: true);
    expect(queries, 2, reason: 'showing it again catches up once');
    expect(find.text('5678'), findsOneWidget);
  });

  testWidgets(
    'showing the page again after an unchanged gallery does not reload',
    (tester) async {
      await _show(tester, container, visible: true);
      await _show(tester, container, visible: false);
      await _show(tester, container, visible: true);

      expect(queries, 1);
    },
  );

  test('the invalidation listener lives exactly as long as the notifier', () {
    final before = cacheManager.debugStatisticsListenerCount;
    final scoped = ProviderContainer();

    scoped.read(statisticsNotifierProvider);
    expect(cacheManager.debugStatisticsListenerCount, before + 1);

    scoped.dispose();
    expect(cacheManager.debugStatisticsListenerCount, before);
    cacheManager.invalidateStatistics();
  });
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container, {
  required bool visible,
}) async {
  tester.view.physicalSize = const Size(1180, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        // Shell branches stay mounted while hidden and only flip visibility.
        home: AppBranchVisibility(
          isVisible: visible,
          child: const StatisticsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GalleryDashboardSnapshot _snapshot(int totalImages) {
  return GalleryDashboardSnapshot(
    totalImages: totalImages,
    totalSizeBytes: totalImages * 1024,
    favoriteCount: 0,
    taggedImageCount: 0,
    imagesWithMetadata: 0,
    resolutionCounts: const {},
    modelCounts: const {},
    samplerCounts: const {},
    sizeCounts: const {},
    tagCounts: const {},
    dailyCounts: const {20260930: 1},
    hourlyCounts: const {10: 1},
    weekdayCounts: const {DateTime.wednesday: 1},
  );
}
