import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/cache/tag_cache_service.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/services/search_index_service.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = Directory(
      'tool/.tmp/startup-cache-test-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    await hiveDirectory.create(recursive: true);
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('tag cache 初始化合并并发调用，并清理损坏数据', () async {
    final box = await Hive.openBox<dynamic>(TagCacheService.boxName);
    await box.put(TagCacheService.cacheDataKey, '{invalid json');
    await box.close();

    final service = TagCacheService();
    final first = service.init();
    final second = service.init();

    expect(identical(first, second), isTrue);
    await first;
    expect(
      Hive.box<dynamic>(TagCacheService.boxName).get(
        TagCacheService.cacheDataKey,
      ),
      isNull,
    );
  });

  test('search index 初始化合并并发调用，并清理损坏数据', () async {
    final box = await Hive.openBox<dynamic>(StorageKeys.searchIndexBox);
    await box.put('inverted_index', '{invalid json');
    await box.put('documents', '{invalid json');
    await box.put('index_metadata', '{invalid json');
    await box.close();

    final service = SearchIndexService();
    final first = service.init();
    final second = service.init();

    expect(identical(first, second), isTrue);
    await first;
    expect(Hive.box<dynamic>(StorageKeys.searchIndexBox).isEmpty, isTrue);
  });
}
