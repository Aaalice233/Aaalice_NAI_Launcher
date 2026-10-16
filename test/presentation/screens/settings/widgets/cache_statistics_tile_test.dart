import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/cache_statistics_tile.dart';

void main() {
  final manager = GalleryCacheManager();
  final l10n = lookupAppLocalizations(const Locale('zh'));
  late int computeCount;

  setUp(() {
    computeCount = 0;
    manager.debugSetStatisticsComputerForTesting(() async {
      computeCount++;
      return _statisticsWithImages(computeCount);
    });
  });

  tearDown(() => manager.debugSetStatisticsComputerForTesting(null));

  String databaseLine(int imageCount) =>
      l10n.cacheStats_databaseValue(imageCount, 0);

  testWidgets('定时刷新走缓存，立即刷新与重置在有效期内拿到新值', (tester) async {
    await tester.pumpWidget(_buildTile());
    await tester.pump();
    expect(computeCount, 1);
    expect(find.text(databaseLine(1)), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(computeCount, 1);
    expect(find.text(databaseLine(1)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.cacheStats_refreshNow));
    await tester.pump();
    await tester.pump();
    expect(computeCount, 2);
    expect(find.text(databaseLine(2)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.cacheStats_resetStats));
    await tester.pump();
    await tester.pump();
    expect(computeCount, 3);
    expect(find.text(databaseLine(3)), findsOneWidget);

    // 等提示自动消失，再卸载以停掉定时器
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });

  test('统计 provider 重建与销毁时成对注册和注销失效监听', () async {
    final before = manager.debugStatisticsListenerCount;
    final container = ProviderContainer();
    final subscription = container.listen(
      cacheStatisticsProvider,
      (_, _) {},
    );

    await container.read(cacheStatisticsProvider.future);
    expect(manager.debugStatisticsListenerCount, before + 1);

    manager.invalidateStatistics();
    final refreshed = await container.read(cacheStatisticsProvider.future);
    expect(refreshed.l3DatabaseImageCount, 2);
    expect(manager.debugStatisticsListenerCount, before + 1);

    subscription.close();
    container.dispose();
    expect(manager.debugStatisticsListenerCount, before);

    manager.invalidateStatistics();
    expect(computeCount, 2);
  });
}

Widget _buildTile() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: CacheStatisticsTile()),
      ),
    ),
  );
}

CacheStatistics _statisticsWithImages(int imageCount) => CacheStatistics(
  l1MemorySize: 0,
  l1HitRate: 0,
  l1MemoryBytes: 0,
  l2HiveSize: 0,
  l2HitRate: 0,
  l2HiveBytes: 0,
  l3DatabaseImageCount: imageCount,
  l3DatabaseMetadataCount: 0,
  totalHitRate: 0,
  lastUpdated: DateTime(2026),
);
