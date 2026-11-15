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

final zhDictionaryServiceProvider =
    NotifierProvider<ZhDictionaryNotifier, ZhDictionaryService>(
      ZhDictionaryNotifier.new,
    );

class ZhDictionaryNotifier extends Notifier<ZhDictionaryService> {
  ZhDictionaryNotifier([this._injectedService]);

  final ZhDictionaryService? _injectedService;

  @override
  ZhDictionaryService build() {
    final service = _injectedService ?? ZhDictionaryService();
    void listener() {
      if (ref.mounted) {
        ref.notifyListeners();
      }
    }

    service.addListener(listener);
    ref.onDispose(() {
      service.removeListener(listener);
      service.dispose();
    });
    if (_injectedService == null) {
      unawaited(() async {
        await service.initialize();
        if (service.state.isInstalled) {
          await service.checkForUpdate();
        }
      }());
    }
    return service;
  }
}

final fastTagServiceProvider = Provider<FastTagService>((ref) {
  // Download/check progress does not change translation content or its cache.
  final dictionary = ref
      .watch(
        zhDictionaryServiceProvider.select(
          (service) => (
            service,
            service.state.isInstalled,
            service.state.version,
            service.state.tagCount,
          ),
        ),
      )
      .$1;
  return FastTagService(
    catalog: ref.watch(tagCatalogRepositoryProvider),
    dictionary: dictionary,
  );
});
