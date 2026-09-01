import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('交互重任务属于 warmup readiness，不能退回主页后的 deferred 启动', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final deferredStart = mainSource.indexOf(
      'Future<void> _runDeferredStartup',
    );
    final deferredEnd = mainSource.indexOf('\nvoid main()', deferredStart);
    expect(deferredStart, greaterThanOrEqualTo(0));
    expect(deferredEnd, greaterThan(deferredStart));

    final deferredSource = mainSource.substring(deferredStart, deferredEnd);
    for (final forbidden in <String>[
      'Random tag library preload',
      'L2 cache cleanup',
      'Temp files cleanup',
      'Search index service initialization',
      'Tag cache service initialization',
      'Isolate metadata service initialization',
    ]) {
      expect(deferredSource, isNot(contains(forbidden)), reason: forbidden);
    }

    final readinessSource = File(
      'lib/presentation/providers/startup_initialization_provider.dart',
    ).readAsStringSync();
    for (final required in <String>[
      'randomTagLibraryDataSourceProvider',
      'searchIndexServiceProvider',
      'tagCacheServiceProvider',
      'IsolateMetadataService.instance.initialize',
      'L2CacheCleaner().checkAndClean',
      'TempImageService().cleanupOldTempFiles',
    ]) {
      expect(readinessSource, contains(required), reason: required);
    }
    expect(mainSource, isNot(contains('SearchIndexService().init')));
    expect(mainSource, isNot(contains('TagCacheService().init')));

    for (final servicePath in <String>[
      'lib/core/cache/tag_cache_service.dart',
      'lib/data/services/search_index_service.dart',
    ]) {
      expect(
        File(servicePath).readAsStringSync(),
        contains('@Riverpod(keepAlive: true)'),
        reason: '$servicePath 必须在整个 ProviderContainer 生命周期复用同一实例',
      );
    }
  });
}
