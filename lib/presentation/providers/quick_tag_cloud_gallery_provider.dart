import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import '../../data/services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import '../../data/services/online_gallery/quick_tag_cloud_user_service.dart';

final quickTagCloudCatalogServiceProvider =
    Provider<QuickTagCloudRemoteCatalogService>(
      (ref) => QuickTagCloudRemoteCatalogService(),
    );

final quickTagCloudUserServiceProvider = Provider<QuickTagCloudUserService>(
  (ref) => QuickTagCloudUserService(ref.watch(localStorageServiceProvider)),
);

final quickTagCloudFilterProvider =
    NotifierProvider<QuickTagCloudFilterNotifier, QuickTagCloudGalleryQuery>(
      QuickTagCloudFilterNotifier.new,
    );

class QuickTagCloudFilterNotifier extends Notifier<QuickTagCloudGalleryQuery> {
  @override
  QuickTagCloudGalleryQuery build() => const QuickTagCloudGalleryQuery();

  Future<bool> initializeContentAccess() async {
    final service = ref.read(quickTagCloudUserServiceProvider);
    await service.ensureInitialized();
    final access = service.contentAccess;
    final filters = service.browsingFilters;
    final next = QuickTagCloudGalleryQuery(
      codexId: filters.codexId,
      categoryPath: List.unmodifiable(filters.categoryPath),
      updateFilterId: filters.updateFilterId,
      scope: QuickTagCloudBrowseScope.values.firstWhere(
        (value) => value.name == filters.scope,
        orElse: () => QuickTagCloudBrowseScope.catalog,
      ),
      mediaFilter: QuickTagCloudMediaFilter.values.firstWhere(
        (value) => value.name == filters.mediaFilter,
        orElse: () => QuickTagCloudMediaFilter.all,
      ),
      allowNsfw: access.allowNsfw,
      allowR18g: access.allowR18g,
      favoritesOnly: state.favoritesOnly,
    );
    if (next.stableKey == state.stableKey) return false;
    state = next;
    return true;
  }

  void restoreBrowsingSessionFilters(QuickTagCloudGalleryQuery restored) {
    state = QuickTagCloudGalleryQuery(
      codexId: restored.codexId,
      categoryPath: List.unmodifiable(restored.categoryPath),
      updateFilterId: restored.updateFilterId,
      scope: restored.scope,
      mediaFilter: restored.mediaFilter,
      allowNsfw: state.allowNsfw,
      allowR18g: state.allowR18g,
      favoritesOnly: state.favoritesOnly,
    );
  }

  void selectCodex(String codexId) {
    state = _copyWith(
      codexId: codexId,
      categoryPath: const [],
      updateFilterId: '',
    );
    _persistBrowsingFilters();
  }

  void selectCategory(List<String> categoryPath) {
    state = _copyWith(categoryPath: List.unmodifiable(categoryPath));
    _persistBrowsingFilters();
  }

  void selectUpdateFilter(String updateFilterId) {
    state = _copyWith(updateFilterId: updateFilterId);
    _persistBrowsingFilters();
  }

  void selectScope(QuickTagCloudBrowseScope scope) {
    state = _copyWith(scope: scope);
    _persistBrowsingFilters();
  }

  void selectMediaFilter(QuickTagCloudMediaFilter mediaFilter) {
    state = _copyWith(mediaFilter: mediaFilter);
    _persistBrowsingFilters();
  }

  Future<void> applyFilters({
    required String codexId,
    required String updateFilterId,
    required QuickTagCloudBrowseScope scope,
    required QuickTagCloudMediaFilter mediaFilter,
    required bool allowNsfw,
    required bool allowR18g,
  }) async {
    final normalizedR18g = allowNsfw && allowR18g;
    final accessChanged =
        state.allowNsfw != allowNsfw || state.allowR18g != normalizedR18g;
    if (accessChanged) {
      await ref
          .read(quickTagCloudUserServiceProvider)
          .setContentAccess(
            QuickTagCloudContentAccessSettings(
              allowNsfw: allowNsfw,
              allowR18g: normalizedR18g,
            ),
          );
    }
    state = QuickTagCloudGalleryQuery(
      codexId: codexId,
      categoryPath: codexId == state.codexId ? state.categoryPath : const [],
      updateFilterId: updateFilterId,
      scope: scope,
      mediaFilter: mediaFilter,
      allowNsfw: allowNsfw,
      allowR18g: normalizedR18g,
      favoritesOnly: state.favoritesOnly,
    );
    await _saveBrowsingFilters();
  }

  Future<void> setContentAccess({
    required bool allowNsfw,
    required bool allowR18g,
  }) => applyFilters(
    codexId: state.codexId,
    updateFilterId: state.updateFilterId,
    scope: state.scope,
    mediaFilter: state.mediaFilter,
    allowNsfw: allowNsfw,
    allowR18g: allowR18g,
  );

  void _persistBrowsingFilters() {
    unawaited(_saveBrowsingFilters());
  }

  Future<void> _saveBrowsingFilters() async {
    try {
      await ref
          .read(quickTagCloudUserServiceProvider)
          .setBrowsingFilters(
            QuickTagCloudBrowsingFilters(
              codexId: state.codexId,
              categoryPath: state.categoryPath,
              updateFilterId: state.updateFilterId,
              scope: state.scope.name,
              mediaFilter: state.mediaFilter.name,
            ),
          );
    } catch (error, stack) {
      AppLogger.w(
        'Failed to save QuickTagCloud browsing filters: $error\n$stack',
        'QuickTagCloud',
      );
    }
  }

  QuickTagCloudGalleryQuery _copyWith({
    String? codexId,
    List<String>? categoryPath,
    String? updateFilterId,
    QuickTagCloudBrowseScope? scope,
    QuickTagCloudMediaFilter? mediaFilter,
    bool? allowNsfw,
    bool? allowR18g,
  }) => QuickTagCloudGalleryQuery(
    codexId: codexId ?? state.codexId,
    categoryPath: categoryPath ?? state.categoryPath,
    updateFilterId: updateFilterId ?? state.updateFilterId,
    scope: scope ?? state.scope,
    mediaFilter: mediaFilter ?? state.mediaFilter,
    allowNsfw: allowNsfw ?? state.allowNsfw,
    allowR18g: allowR18g ?? state.allowR18g,
    favoritesOnly: state.favoritesOnly,
  );
}
