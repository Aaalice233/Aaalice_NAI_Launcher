import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_auth_scope_coordinator.dart';
import '../../data/services/online_gallery/online_gallery_search_service.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'online_gallery_state.dart';

class OnlineGalleryLifecycleService {
  OnlineGalleryLifecycleService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required void Function() cancelCurrentRequest,
    required Future<void> Function({bool refresh}) loadPosts,
    required Future<void> Function({required bool replace, bool restart})
    loadRandom,
    required OnlineGallerySearchService search,
    required void Function() clearDetails,
    required void Function() invalidateRandomSnapshot,
    required Set<String> Function() localFavoriteKeys,
    required void Function(Set<String> keys) setLocalFavoriteKeys,
    required Set<String> Function() remoteFavoriteKeys,
  }) : _ref = ref,
       _readState = readState,
       _reduce = reduce,
       _cancelCurrentRequest = cancelCurrentRequest,
       _loadPosts = loadPosts,
       _loadRandom = loadRandom,
       _search = search,
       _clearDetails = clearDetails,
       _invalidateRandomSnapshot = invalidateRandomSnapshot,
       _localFavoriteKeys = localFavoriteKeys,
       _setLocalFavoriteKeys = setLocalFavoriteKeys,
       _remoteFavoriteKeys = remoteFavoriteKeys;

  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final void Function() _cancelCurrentRequest;
  final Future<void> Function({bool refresh}) _loadPosts;
  final Future<void> Function({required bool replace, bool restart})
  _loadRandom;
  final OnlineGallerySearchService _search;
  final void Function() _clearDetails;
  final void Function() _invalidateRandomSnapshot;
  final Set<String> Function() _localFavoriteKeys;
  final void Function(Set<String> keys) _setLocalFavoriteKeys;
  final Set<String> Function() _remoteFavoriteKeys;
  final OnlineGalleryAuthScopeCoordinator _authScopes =
      const OnlineGalleryAuthScopeCoordinator();
  final Map<GallerySourceId, bool> _pendingAuthenticationChanges = {};
  Timer? _blacklistRefreshDebounce;
  Timer? _authenticationChangeTimer;
  bool _disposed = false;
  bool _danbooruAuthReady = false;
  bool _gelbooruAuthReady = false;

  bool get disposed => _disposed;

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  String get currentDanbooruAuthScope =>
      _authScopes.danbooruScope(_ref.read(danbooruAuthProvider));
  String get currentGelbooruAuthScope =>
      _authScopes.gelbooruScope(_ref.read(gelbooruAuthProvider));

  void attach() {
    if (Hive.isBoxOpen(StorageKeys.localFavoritesBox)) {
      Future.microtask(() async {
        await _ref
            .read(onlineGalleryLocalFavoritesProvider.notifier)
            .initialize();
        _handleLocalFavoritesChanged(reloadFavorites: false);
      });
      _ref.listen<(bool, int)>(
        onlineGalleryLocalFavoritesProvider.select(
          (value) => (value.isInitialized, value.revision),
        ),
        (previous, next) => _handleLocalFavoritesChanged(
          reloadFavorites: previous?.$2 != next.$2,
        ),
      );
    }
    _ref.listen<(String?, String?, int?, bool)>(
      danbooruAuthProvider.select(
        (value) => (
          value.credentials?.username,
          value.user?.name,
          value.user?.level,
          value.isLoggedIn,
        ),
      ),
      (_, _) {
        if (_danbooruAuthReady) _queueAuthChange(GallerySourceId.danbooru);
      },
    );
    _ref.listen<(String?, GelbooruAuthStatus)>(
      gelbooruAuthProvider.select(
        (value) => (value.credentials?.userId.toString(), value.status),
      ),
      (_, next) {
        if (_gelbooruAuthReady) {
          _queueAuthChange(
            GallerySourceId.gelbooru,
            deferWhileLoading: next.$2 == GelbooruAuthStatus.invalid,
          );
        }
      },
    );
    _ref.listen<int>(
      onlineGalleryBlacklistNotifierProvider.select((value) => value.revision),
      (_, _) => _handleBlacklistChanged(),
    );
    unawaited(Future<void>(_initializeAuthenticationScopes));
  }

  void dispose() {
    _disposed = true;
    _blacklistRefreshDebounce?.cancel();
    _authenticationChangeTimer?.cancel();
  }

  void flushAuthenticationChanges() {
    _authenticationChangeTimer = null;
    if (_disposed || _pendingAuthenticationChanges.isEmpty) return;
    final requestActive = state.isLoading || state.isLoadingMore;
    final ready = _pendingAuthenticationChanges.entries
        .where((entry) => !requestActive || !entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final sourceId in ready) {
      _pendingAuthenticationChanges.remove(sourceId);
      _handleAuthenticationChanged(sourceId);
    }
  }

  Future<void> ensureAuthenticationReady(GallerySourceId sourceId) async {
    switch (sourceId) {
      case GallerySourceId.danbooru:
        await _ensureAuth(
          () => _ref.read(danbooruAuthProvider.notifier).ensureInitialized(),
          'Danbooru',
        );
        if (_disposed) return;
        _danbooruAuthReady = true;
        final scope = currentDanbooruAuthScope;
        if (scope != state.danbooruAuthScope) {
          state = state.copyWith(danbooruAuthScope: scope);
        }
        return;
      case GallerySourceId.gelbooru:
        await _ensureAuth(
          () => _ref.read(gelbooruAuthProvider.notifier).ensureInitialized(),
          'Gelbooru',
        );
        if (_disposed) return;
        _gelbooruAuthReady = true;
        final scope = currentGelbooruAuthScope;
        if (scope != state.gelbooruAuthScope) {
          state = state.copyWith(gelbooruAuthScope: scope);
        }
        return;
      case GallerySourceId.safebooru:
      case GallerySourceId.aiTag:
      case GallerySourceId.quickTagCloud:
        return;
    }
  }

  Future<void> _initializeAuthenticationScopes() async {
    if (_disposed) return;
    try {
      await Future.wait([
        _ref.read(danbooruAuthProvider.notifier).ensureInitialized(),
        _ref.read(gelbooruAuthProvider.notifier).ensureInitialized(),
      ]);
    } catch (error) {
      if (_disposed) return;
      AppLogger.w(
        'Failed to initialize online gallery authentication scopes: $error',
        'OnlineGallery',
      );
    }
    if (_disposed) return;
    final initializeDanbooru = !_danbooruAuthReady;
    final initializeGelbooru = !_gelbooruAuthReady;
    _danbooruAuthReady = true;
    _gelbooruAuthReady = true;
    state = state.copyWith(
      danbooruAuthScope: initializeDanbooru
          ? currentDanbooruAuthScope
          : state.danbooruAuthScope,
      gelbooruAuthScope: initializeGelbooru
          ? currentGelbooruAuthScope
          : state.gelbooruAuthScope,
    );
  }

  Future<void> _ensureAuth(
    Future<void> Function() initialize,
    String source,
  ) async {
    try {
      await initialize();
    } catch (error) {
      AppLogger.w(
        'Failed to initialize $source authentication: $error',
        'OnlineGallery',
      );
    }
  }

  void _handleLocalFavoritesChanged({bool reloadFavorites = true}) {
    final localState = _ref.read(onlineGalleryLocalFavoritesProvider);
    if (!localState.isInitialized) return;
    final nextLocalKeys = _ref
        .read(onlineGalleryLocalFavoritesRepositoryProvider)
        .stableKeys;
    _setLocalFavoriteKeys(nextLocalKeys);
    state = state.copyWith(
      caches: {
        for (final entry in state.caches.entries)
          if (!entry.key.startsWith('favorites:')) entry.key: entry.value,
      },
      favoritedPostKeys: {...nextLocalKeys, ..._remoteFavoriteKeys()},
      localFavoritedPostKeys: nextLocalKeys,
      remoteFavoritedPostKeys: _remoteFavoriteKeys(),
    );
    if (reloadFavorites && state.viewMode == GalleryViewMode.favorites) {
      _cancelCurrentRequest();
      if (state.randomEnabled) {
        state = state.copyWith(randomSession: const RandomGallerySession());
      }
      unawaited(_loadPosts(refresh: true));
    }
  }

  void _handleBlacklistChanged() {
    _blacklistRefreshDebounce?.cancel();
    _blacklistRefreshDebounce = Timer(const Duration(milliseconds: 150), () {
      _cancelCurrentRequest();
      if (state.randomEnabled) {
        state = state.copyWith(
          blacklistRevision: state.blacklistRevision + 1,
          randomSession: const RandomGallerySession(),
          clearError: true,
        );
        unawaited(_loadRandom(replace: true, restart: true));
      } else {
        state = state
            .copyWith(blacklistRevision: state.blacklistRevision + 1)
            .updateCurrentCache(const ModeCache());
        unawaited(_loadPosts(refresh: true));
      }
    });
  }

  void _queueAuthChange(
    GallerySourceId sourceId, {
    bool deferWhileLoading = false,
  }) {
    final existing = _pendingAuthenticationChanges[sourceId];
    _pendingAuthenticationChanges[sourceId] = existing == null
        ? deferWhileLoading
        : existing && deferWhileLoading;
    _authenticationChangeTimer ??= Timer(
      Duration.zero,
      flushAuthenticationChanges,
    );
  }

  void _handleAuthenticationChanged(GallerySourceId sourceId) {
    final nextScope = sourceId == GallerySourceId.danbooru
        ? currentDanbooruAuthScope
        : currentGelbooruAuthScope;
    final currentScope = sourceId == GallerySourceId.danbooru
        ? state.danbooruAuthScope
        : state.gelbooruAuthScope;
    if (nextScope == currentScope) return;
    final active = state.activeSourceId == sourceId;
    if (active) _cancelCurrentRequest();
    final sourcePrefix = '${sourceId.key}:';
    _search.clearSource(sourceId);
    _clearDetails();
    _remoteFavoriteKeys().removeWhere((key) => key.startsWith(sourcePrefix));
    if (state.randomEnabled) _invalidateRandomSnapshot();
    state = state.copyWith(
      caches: {
        for (final entry in state.caches.entries)
          if (!_authScopes.ownsAuthenticatedCache(entry.key, sourceId))
            entry.key: entry.value,
      },
      searchCache: const ModeCache(),
      popularCache: const ModeCache(),
      danbooruAuthScope: sourceId == GallerySourceId.danbooru
          ? nextScope
          : state.danbooruAuthScope,
      gelbooruAuthScope: sourceId == GallerySourceId.gelbooru
          ? nextScope
          : state.gelbooruAuthScope,
      randomSession: active && state.randomEnabled
          ? const RandomGallerySession()
          : state.randomSession,
      favoritedPostKeys: {..._localFavoriteKeys(), ..._remoteFavoriteKeys()},
      localFavoritedPostKeys: _localFavoriteKeys(),
      remoteFavoritedPostKeys: _remoteFavoriteKeys(),
      clearError: active,
    );
    if (!active) return;
    state.randomEnabled
        ? unawaited(_loadRandom(replace: true, restart: true))
        : unawaited(_loadPosts(refresh: true));
  }
}
