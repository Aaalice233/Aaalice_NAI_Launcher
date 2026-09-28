import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';

void main() {
  test(
    'initialization preserves filters changed while storage is loading',
    () async {
      final service = _DeferredQuickTagCloudUserService(
        storage: _MockLocalStorageService(),
        browsingFilters: const QuickTagCloudBrowsingFilters(
          codexId: 'persisted',
          categoryPath: ['Old category'],
        ),
        contentAccess: const QuickTagCloudContentAccessSettings(
          allowNsfw: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          quickTagCloudUserServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(quickTagCloudFilterProvider.notifier);

      final firstInitialization = notifier.initializeContentAccess();
      final concurrentInitialization = notifier.initializeContentAccess();
      expect(identical(firstInitialization, concurrentInitialization), isTrue);

      notifier.selectCodex('selected');
      notifier.selectCategory(const ['New category']);
      service.completeInitialization();

      await Future.wait([firstInitialization, concurrentInitialization]);
      final query = container.read(quickTagCloudFilterProvider);
      expect(query.codexId, 'selected');
      expect(query.categoryPath, const ['New category']);
      expect(query.allowNsfw, isTrue);
      expect(service.ensureInitializedCalls, 1);

      expect(await notifier.initializeContentAccess(), isFalse);
      expect(service.ensureInitializedCalls, 1);
      expect(container.read(quickTagCloudFilterProvider).codexId, 'selected');
    },
  );
}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

class _DeferredQuickTagCloudUserService extends QuickTagCloudUserService {
  _DeferredQuickTagCloudUserService({
    required LocalStorageService storage,
    required this.browsingFilters,
    required this.contentAccess,
  }) : super(storage);

  final Completer<void> _initialization = Completer<void>();

  @override
  final QuickTagCloudBrowsingFilters browsingFilters;

  @override
  final QuickTagCloudContentAccessSettings contentAccess;

  int ensureInitializedCalls = 0;

  @override
  Future<void> ensureInitialized() {
    ensureInitializedCalls++;
    return _initialization.future;
  }

  void completeInitialization() => _initialization.complete();

  @override
  Future<void> setBrowsingFilters(QuickTagCloudBrowsingFilters filters) async {}

  @override
  Future<void> setContentAccess(
    QuickTagCloudContentAccessSettings settings,
  ) async {}
}
