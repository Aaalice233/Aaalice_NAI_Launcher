import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fast_tag_service.dart';
import 'tag_catalog_repository.dart';
import 'zh_dictionary_service.dart';

final tagCatalogRepositoryProvider = Provider<TagCatalogRepository>((ref) {
  final repository = TagCatalogRepository();
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final zhDictionaryServiceProvider = ChangeNotifierProvider<ZhDictionaryService>(
  (ref) {
    final service = ZhDictionaryService();
    unawaited(() async {
      await service.initialize();
      if (service.state.isInstalled) {
        await service.checkForUpdate();
      }
    }());
    return service;
  },
);

final fastTagServiceProvider = Provider<FastTagService>(
  (ref) => FastTagService(
    catalog: ref.watch(tagCatalogRepositoryProvider),
    dictionary: ref.watch(zhDictionaryServiceProvider),
  ),
);
