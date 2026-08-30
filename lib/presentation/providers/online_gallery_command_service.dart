import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/online_gallery/gallery_tag_query.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/services/gelbooru_auth_service.dart';
import 'online_gallery_state.dart';
import 'quick_tag_cloud_gallery_provider.dart';

class OnlineGalleryCommandService {
  OnlineGalleryCommandService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required void Function() cancelCurrentRequest,
    required Future<void> Function({bool refresh}) loadPosts,
    required Future<void> Function({required bool replace, bool restart})
    loadRandom,
    required void Function() clearDetailCache,
  }) : _ref = ref,
       _readState = readState,
       _reduce = reduce,
       _cancelRequest = cancelCurrentRequest,
       _loadPosts = loadPosts,
       _loadRandom = loadRandom,
       _clearDetailCache = clearDetailCache;

  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final void Function() _cancelRequest;
  final Future<void> Function({bool refresh}) _loadPosts;
  final Future<void> Function({required bool replace, bool restart})
  _loadRandom;
  final void Function() _clearDetailCache;
  OnlineGalleryState? _normalRestorePoint;
  int _continuationGeneration = 0;
  bool _disposed = false;

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  void dispose() {
    _disposed = true;
    _continuationGeneration++;
  }

  void _cancelCurrentRequest() {
    _continuationGeneration++;
    _cancelRequest();
  }

  bool _isCurrentContinuation(int generation, {GallerySourceId? sourceId}) =>
      !_disposed &&
      generation == _continuationGeneration &&
      (sourceId == null || state.activeSourceId == sourceId);

  void restoreRandomSnapshot(OnlineGalleryState restored) {
    if (restored.randomEnabled) {
      _normalRestorePoint = restored.copyWith(randomEnabled: false);
    }
  }

  void invalidateRandomSnapshot() => _normalRestorePoint = null;

  void saveScrollOffset(
    double offset, {
    String? anchorStableKey,
    double anchorLocalOffset = 0,
  }) {
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    final cache = activeCache.copyWith(
      scrollOffset: offset,
      anchorStableKey: anchorStableKey,
      anchorLocalOffset: anchorLocalOffset,
    );
    state = state.randomEnabled
        ? state.copyWith(
            randomSession: state.randomSession.copyWith(cache: cache),
          )
        : state.updateCurrentCache(cache);
  }

  Future<void> switchToSearch() async {
    if (state.viewMode == GalleryViewMode.search) return;
    final sourceId = state.activeSourceId;
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.search,
      sourceId: sourceId,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? _ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearError: true,
    );
    await _loadIfMissing();
  }

  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;
    final sourceId = state.activeSourceId;
    if (!sourceId.capabilities.supportsRanking) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.popular,
      popularSourceId: sourceId,
      clearError: true,
    );
    await _loadIfMissing();
  }

  Future<void> switchToFavorites() async {
    final sourceId = state.activeSourceId;
    if (!sourceId.capabilities.supportsLocalFavorites) return;
    final generation = _continuationGeneration;
    if (sourceId == GallerySourceId.gelbooru) {
      await _ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
      if (!_isCurrentContinuation(generation, sourceId: sourceId)) return;
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: sourceId,
      clearError: true,
    );
    await _loadIfMissing();
  }

  Future<void> setSource(
    Object source, {
    String? draftQuery,
    String? draftPrompt,
  }) async {
    final sourceId = normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsSearch) return;
    final normalizedQuery = (draftQuery ?? state.searchQuery).trim();
    final normalizedPrompt = (draftPrompt ?? state.promptQuery).trim();
    if (state.sourceId == sourceId &&
        state.searchQuery == normalizedQuery &&
        state.promptQuery == normalizedPrompt) {
      return;
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      sourceId: sourceId,
      searchQuery: normalizedQuery,
      promptQuery: normalizedPrompt,
      popularSourceId: sourceId.capabilities.supportsRanking
          ? sourceId
          : state.popularSourceId,
      favoritesSourceId: sourceId.capabilities.supportsLocalFavorites
          ? sourceId
          : state.favoritesSourceId,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? _ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearAiTagConfig: sourceId != GallerySourceId.aiTag,
      clearDateRange: true,
      clearError: true,
    );
    if (!GalleryTagQueryParser.parse(normalizedQuery).isValid) {
      state = state.copyWith(
        errorCode: OnlineGalleryErrorCode.tooManySearchTags,
      );
      return;
    }
    await _loadPosts(refresh: true);
  }

  Future<void> setPopularSource(
    Object source, {
    String? draftQuery,
    String? draftPrompt,
  }) async {
    final sourceId = normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsRanking) return;
    final normalizedQuery = (draftQuery ?? state.popularQuery).trim();
    final normalizedPrompt = (draftPrompt ?? state.popularPromptQuery).trim();
    if (state.popularSourceId == sourceId &&
        state.popularQuery == normalizedQuery &&
        state.popularPromptQuery == normalizedPrompt) {
      return;
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      sourceId: sourceId,
      popularSourceId: sourceId,
      popularQuery: normalizedQuery,
      popularPromptQuery: normalizedPrompt,
      favoritesSourceId: sourceId.capabilities.supportsLocalFavorites
          ? sourceId
          : state.favoritesSourceId,
      clearAiTagConfig: sourceId != GallerySourceId.aiTag,
      clearDateRange: true,
      clearError: true,
    );
    if (!GalleryTagQueryParser.parse(normalizedQuery).isValid) {
      state = state.copyWith(
        errorCode: OnlineGalleryErrorCode.tooManySearchTags,
      );
      return;
    }
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> setFavoritesSource(Object source, {String? draftQuery}) async {
    final sourceId = normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsLocalFavorites) {
      return;
    }
    final normalizedQuery = (draftQuery ?? state.favoriteSearchQuery).trim();
    if (state.favoritesSourceId == sourceId &&
        state.favoriteSearchQuery == normalizedQuery) {
      return;
    }
    _cancelCurrentRequest();
    final generation = _continuationGeneration;
    if (sourceId == GallerySourceId.gelbooru) {
      await _ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
      if (!_isCurrentContinuation(generation)) return;
    }
    state = state.copyWith(
      sourceId: sourceId,
      popularSourceId: sourceId.capabilities.supportsRanking
          ? sourceId
          : state.popularSourceId,
      favoritesSourceId: sourceId,
      favoriteSearchQuery: normalizedQuery,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? _ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearAiTagConfig: sourceId != GallerySourceId.aiTag,
      clearDateRange: true,
      clearError: true,
      clearNotice: true,
    );
    if (state.viewMode == GalleryViewMode.favorites) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> searchFavorites(String query) async {
    final normalized = query.trim();
    _cancelCurrentRequest();
    state = state.copyWith(
      favoriteSearchQuery: normalized,
      viewMode: GalleryViewMode.favorites,
      clearError: true,
    );
    await _loadPosts(refresh: true);
  }

  void syncQuickTagCloudFilterKey() {
    final key = _ref.read(quickTagCloudFilterProvider).stableKey;
    if (state.quickTagCloudFilterKey == key) return;
    _cancelCurrentRequest();
    state = state.copyWith(quickTagCloudFilterKey: key, clearError: true);
  }

  Future<void> ensureQuickTagCloudFilterInitialized() async {
    const sourceId = GallerySourceId.quickTagCloud;
    if (state.activeSourceId != sourceId) return;
    final generation = _continuationGeneration;
    final notifier = _ref.read(quickTagCloudFilterProvider.notifier);
    final restored = QuickTagCloudGalleryQuery.tryParseStableKey(
      state.quickTagCloudFilterKey,
    );
    await notifier.initializeContentAccess();
    if (!_isCurrentContinuation(generation, sourceId: sourceId)) return;
    if (restored != null &&
        state.quickTagCloudFilterKey !=
            QuickTagCloudGalleryQuery.defaultStableKey) {
      notifier.restoreBrowsingSessionFilters(restored);
    }
    if (!_isCurrentContinuation(generation, sourceId: sourceId)) return;
    final key = _ref.read(quickTagCloudFilterProvider).stableKey;
    if (state.quickTagCloudFilterKey != key) {
      state = state.copyWith(quickTagCloudFilterKey: key, clearError: true);
    }
  }

  void clearDetailCache() => _clearDetailCache();

  Future<void> setPopularScale(PopularScale scale) async {
    if (state.popularScale == scale) return;
    _cancelCurrentRequest();
    state = state.copyWith(popularScale: scale, clearError: true);
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> setPopularDate(DateTime? date) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      popularDate: date,
      clearPopularDate: date == null,
      clearError: true,
    );
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> setAiTagTimeRange(String range) async {
    if (state.aiTagTimeRange == range) return;
    _cancelCurrentRequest();
    state = state.copyWith(aiTagTimeRange: range, clearError: true);
    if (state.viewMode == GalleryViewMode.search &&
        state.sourceId == GallerySourceId.aiTag) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> setAiTagPopularPeriod(String period) async {
    if (state.aiTagPopularPeriod == period) return;
    _cancelCurrentRequest();
    state = state.copyWith(aiTagPopularPeriod: period, clearError: true);
    if (state.viewMode == GalleryViewMode.popular &&
        state.popularSourceId == GallerySourceId.aiTag) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> setArtistHuntEnabled(bool enabled) async {
    if (state.artistHuntEnabled == enabled) return;
    _cancelCurrentRequest();
    _normalRestorePoint = _normalRestorePoint?.copyWith(
      artistHuntEnabled: enabled,
      clearError: true,
    );
    state = state.copyWith(artistHuntEnabled: enabled, clearError: true);
    if (state.randomEnabled) {
      state = state.copyWith(randomSession: const RandomGallerySession());
      await _loadRandom(replace: true, restart: true);
    } else if (state.currentCache.posts.isEmpty) {
      await _loadPosts(refresh: true);
    }
  }

  Future<void> refreshWithDraft({
    required String query,
    required String prompt,
  }) async {
    if (state.randomEnabled) {
      final normalized = query.trim();
      final parsed = GalleryTagQueryParser.parse(normalized);
      _cancelCurrentRequest();
      state = switch (state.viewMode) {
        GalleryViewMode.search => state.copyWith(
          searchQuery: normalized,
          promptQuery: prompt.trim(),
          clearError: true,
        ),
        GalleryViewMode.popular => state.copyWith(
          popularQuery: normalized,
          popularPromptQuery: prompt.trim(),
          clearError: true,
        ),
        GalleryViewMode.favorites => state.copyWith(
          favoriteSearchQuery: normalized,
          clearError: true,
        ),
      };
      if (state.viewMode != GalleryViewMode.favorites && !parsed.isValid) {
        state = state.copyWith(
          errorCode: OnlineGalleryErrorCode.tooManySearchTags,
        );
        return;
      }
      await _loadRandom(replace: true, restart: true);
      return;
    }
    switch (state.viewMode) {
      case GalleryViewMode.search:
        await searchWithPrompt(query, prompt: prompt);
        break;
      case GalleryViewMode.popular:
        await searchPopular(query: query, prompt: prompt);
        break;
      case GalleryViewMode.favorites:
        await searchFavorites(query);
        break;
    }
  }

  Future<void> search(String query) =>
      searchWithPrompt(query, prompt: state.promptQuery);

  Future<void> searchWithPrompt(String query, {required String prompt}) async {
    final normalized = query.trim();
    final parsed = GalleryTagQueryParser.parse(normalized);
    _cancelCurrentRequest();
    state = state.copyWith(
      searchQuery: normalized,
      promptQuery: prompt.trim(),
      viewMode: GalleryViewMode.search,
      clearError: true,
    );
    if (!parsed.isValid) {
      state = state.copyWith(
        errorCode: OnlineGalleryErrorCode.tooManySearchTags,
      );
      return;
    }
    await _loadPosts(refresh: true);
  }

  Future<void> searchPopular({
    required String query,
    required String prompt,
  }) async {
    final normalized = query.trim();
    final parsed = GalleryTagQueryParser.parse(normalized);
    _cancelCurrentRequest();
    state = state.copyWith(
      popularQuery: normalized,
      popularPromptQuery: prompt.trim(),
      viewMode: GalleryViewMode.popular,
      clearError: true,
    );
    if (!parsed.isValid) {
      state = state.copyWith(
        errorCode: OnlineGalleryErrorCode.tooManySearchTags,
      );
      return;
    }
    await _loadPosts(refresh: true);
  }

  Future<void> setFuzzySearchEnabled(bool enabled) async {
    if (state.fuzzySearchEnabled == enabled) return;
    _cancelCurrentRequest();
    state = state.copyWith(fuzzySearchEnabled: enabled, clearError: true);
    await _loadPosts(refresh: true);
  }

  Future<void> setRatings(Set<String> selectedRatings) async {
    final normalized = normalizeRatings(selectedRatings);
    if (setEquals(state.selectedRatings, normalized)) return;
    _cancelCurrentRequest();
    state = state.copyWith(selectedRatings: normalized, clearError: true);
    await _loadPosts(refresh: true);
  }

  Future<void> toggleRating(String rating) async {
    if (rating == 'all') return setRatings(kAllRatings);
    if (!kAllRatings.contains(rating)) return;
    final next = {...state.selectedRatings};
    if (next.contains(rating)) {
      if (next.length == 1) return;
      next.remove(rating);
    } else {
      next.add(rating);
    }
    await setRatings(next);
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      dateRangeStart: start,
      dateRangeEnd: end,
      clearDateRangeStart: start == null,
      clearDateRangeEnd: end == null,
      clearError: true,
    );
    await _loadPosts(refresh: true);
  }

  Future<void> clearDateRange() => setDateRange(null, null);

  Future<void> setRandomEnabled(bool enabled) async {
    if (state.randomEnabled == enabled) return;
    _cancelCurrentRequest();
    if (!enabled) {
      final restore = _normalRestorePoint;
      _normalRestorePoint = null;
      state = (restore ?? state).copyWith(
        randomEnabled: false,
        randomSession: state.randomSession,
        favoritedPostKeys: state.favoritedPostKeys,
        localFavoritedPostKeys: state.localFavoritedPostKeys,
        remoteFavoritedPostKeys: state.remoteFavoritedPostKeys,
        favoriteLoadingPostKeys: state.favoriteLoadingPostKeys,
        aiTagConfig: state.aiTagConfig,
        artistHuntEnabled: state.artistHuntEnabled,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
      if (restore == null && state.currentCache.posts.isEmpty) {
        await _loadPosts(refresh: true);
      }
      return;
    }
    if (!state.supportsRandom) return;
    _normalRestorePoint = state;
    state = state.copyWith(
      randomEnabled: true,
      randomSession: const RandomGallerySession(),
      clearError: true,
    );
    await _loadRandom(replace: true, restart: true);
  }

  Future<void> restartRandom() async {
    if (!state.randomEnabled) return;
    state = state.copyWith(randomSession: const RandomGallerySession());
    await _loadRandom(replace: true, restart: true);
  }

  Future<void> _loadIfMissing() async {
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await _loadPosts(refresh: true);
    }
  }

  static GallerySourceId? normalizeSource(Object source) {
    if (source is GallerySourceId) return source;
    if (source is String &&
        GallerySourceId.values.any((value) => value.key == source)) {
      return GallerySourceId.fromKey(source);
    }
    return null;
  }

  static Set<String> normalizeRatings(Set<String> ratings) {
    final normalized = ratings.where(kAllRatings.contains).toSet();
    return Set.unmodifiable(normalized.isEmpty ? {...kAllRatings} : normalized);
  }

  static bool setEquals(Set<String> left, Set<String> right) =>
      identical(left, right) ||
      (left.length == right.length && left.containsAll(right));
}
