import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/models/online_gallery/gelbooru_post_parser.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import 'online_gallery_blacklist_provider.dart';

part 'online_gallery_provider.g.dart';

const Set<String> kAllRatings = {'g', 's', 'q', 'e'};

String buildOnlineGallerySearchQuery(String query, {required bool fuzzyMatch}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return '';

  final tags = trimmed
      .split(RegExp(r'[,，]'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();

  if (tags.isEmpty) return '';

  final processedTags = tags.map((tag) {
    if (!fuzzyMatch || _isOnlineGallerySpecialTag(tag)) {
      return tag;
    }
    return '*$tag*';
  }).toList();

  return processedTags.join(' ');
}

bool _isOnlineGallerySpecialTag(String tag) {
  if (tag.contains('*')) return true;
  if (tag.contains(':')) return true;
  if (tag.startsWith('-')) return true;
  return false;
}

/// 顶级函数：在 Isolate 中解析帖子数据 (用于 compute)
///
/// 避免主线程阻塞，提升 UI 流畅度
List<DanbooruPost> parsePostsInIsolate(Map<String, dynamic> data) {
  final rawList = data['rawList'] as List;
  final source = data['source'] as String;

  return rawList
      .map((item) {
        final json = item as Map<String, dynamic>;

        // Gelbooru 需要特殊字段映射
        if (source == 'gelbooru') {
          return parseGelbooruPostJson(json);
        }

        // Danbooru/Safebooru 使用标准字段
        return DanbooruPost.fromJson(
          json,
        ).copyWith(site: source == 'safebooru' ? 'safebooru' : 'danbooru');
      })
      .where((post) => post.previewUrl.isNotEmpty)
      .toList();
}

/// 画廊视图模式
enum GalleryViewMode {
  search, // 搜索模式
  popular, // 排行榜模式
  favorites, // 收藏夹模式
}

enum OnlineGalleryErrorCode {
  gelbooruCredentialsRequired,
  gelbooruCredentialsInvalid,
  gelbooruRateLimited,
  gelbooruTimeout,
  gelbooruServer,
  gelbooruNetwork,
  gelbooruMalformedResponse,
  gelbooruRequestFailed,
}

enum OnlineGalleryNotice { gelbooruCredentialsInvalid }

String onlineGalleryPostKey(DanbooruPost post) => '${post.site}:${post.id}';

@Riverpod(keepAlive: true)
Dio onlineGalleryHttpClient(Ref ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}

/// 单个模式的缓存状态
///
/// 每个模式（搜索/排行榜/收藏夹）维护独立的数据和滚动位置
class ModeCache {
  final List<DanbooruPost> posts;
  final int page;
  final bool hasMore;
  final double scrollOffset;

  const ModeCache({
    this.posts = const [],
    this.page = 1,
    this.hasMore = true,
    this.scrollOffset = 0,
  });

  ModeCache copyWith({
    List<DanbooruPost>? posts,
    int? page,
    bool? hasMore,
    double? scrollOffset,
  }) {
    return ModeCache(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }
}

/// 在线画廊状态
///
/// 重构：每个模式维护独立的缓存，切换模式时不丢失数据
class OnlineGalleryState {
  final bool isLoading;
  final String? error;
  final OnlineGalleryErrorCode? errorCode;
  final OnlineGalleryNotice? notice;
  final String searchQuery;
  final bool fuzzySearchEnabled;
  final String source;
  final String favoritesSource;
  final Set<String> selectedRatings;

  /// 视图模式
  final GalleryViewMode viewMode;

  /// 各模式独立缓存
  final ModeCache searchCache;
  final ModeCache popularCache;
  final ModeCache danbooruFavoritesCache;
  final ModeCache gelbooruFavoritesCache;

  /// 排行榜时间范围
  final PopularScale popularScale;

  /// 排行榜日期
  final DateTime? popularDate;

  /// 已收藏的站点限定帖子键集合（例如 danbooru:123）
  final Set<String> favoritedPostKeys;

  /// 正在执行收藏操作的站点限定帖子键集合
  final Set<String> favoriteLoadingPostKeys;

  /// 日期范围筛选（搜索模式）
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  const OnlineGalleryState({
    this.isLoading = false,
    this.error,
    this.errorCode,
    this.notice,
    this.searchQuery = '',
    this.fuzzySearchEnabled = false,
    this.source = 'danbooru',
    this.favoritesSource = 'danbooru',
    this.selectedRatings = kAllRatings,
    this.viewMode = GalleryViewMode.search,
    this.searchCache = const ModeCache(),
    this.popularCache = const ModeCache(),
    this.danbooruFavoritesCache = const ModeCache(),
    this.gelbooruFavoritesCache = const ModeCache(),
    this.popularScale = PopularScale.day,
    this.popularDate,
    this.favoritedPostKeys = const {},
    this.favoriteLoadingPostKeys = const {},
    this.dateRangeStart,
    this.dateRangeEnd,
  });

  /// 获取当前模式的缓存
  ModeCache get currentCache {
    switch (viewMode) {
      case GalleryViewMode.search:
        return searchCache;
      case GalleryViewMode.popular:
        return popularCache;
      case GalleryViewMode.favorites:
        return favoritesCacheFor(favoritesSource);
    }
  }

  ModeCache favoritesCacheFor(String source) {
    return source == 'gelbooru'
        ? gelbooruFavoritesCache
        : danbooruFavoritesCache;
  }

  bool get hasError => error != null || errorCode != null;

  /// 当前模式的帖子列表
  List<DanbooruPost> get posts => currentCache.posts;

  /// 当前模式的页码
  int get page => currentCache.page;

  /// 当前模式是否还有更多
  bool get hasMore => currentCache.hasMore;

  /// 当前模式的滚动位置
  double get scrollOffset => currentCache.scrollOffset;

  OnlineGalleryState copyWith({
    bool? isLoading,
    String? error,
    OnlineGalleryErrorCode? errorCode,
    OnlineGalleryNotice? notice,
    String? searchQuery,
    bool? fuzzySearchEnabled,
    String? source,
    String? favoritesSource,
    Set<String>? selectedRatings,
    GalleryViewMode? viewMode,
    ModeCache? searchCache,
    ModeCache? popularCache,
    ModeCache? danbooruFavoritesCache,
    ModeCache? gelbooruFavoritesCache,
    PopularScale? popularScale,
    DateTime? popularDate,
    Set<String>? favoritedPostKeys,
    Set<String>? favoriteLoadingPostKeys,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearError = false,
    bool clearNotice = false,
    bool clearPopularDate = false,
    bool clearDateRange = false,
  }) {
    return OnlineGalleryState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      notice: clearNotice ? null : (notice ?? this.notice),
      searchQuery: searchQuery ?? this.searchQuery,
      fuzzySearchEnabled: fuzzySearchEnabled ?? this.fuzzySearchEnabled,
      source: source ?? this.source,
      favoritesSource: favoritesSource ?? this.favoritesSource,
      selectedRatings: Set.unmodifiable(
        selectedRatings ?? this.selectedRatings,
      ),
      viewMode: viewMode ?? this.viewMode,
      searchCache: searchCache ?? this.searchCache,
      popularCache: popularCache ?? this.popularCache,
      danbooruFavoritesCache:
          danbooruFavoritesCache ?? this.danbooruFavoritesCache,
      gelbooruFavoritesCache:
          gelbooruFavoritesCache ?? this.gelbooruFavoritesCache,
      popularScale: popularScale ?? this.popularScale,
      popularDate: clearPopularDate ? null : (popularDate ?? this.popularDate),
      favoritedPostKeys: favoritedPostKeys ?? this.favoritedPostKeys,
      favoriteLoadingPostKeys:
          favoriteLoadingPostKeys ?? this.favoriteLoadingPostKeys,
      dateRangeStart: clearDateRange
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
    );
  }

  /// 更新当前模式的缓存
  OnlineGalleryState updateCurrentCache(ModeCache cache) {
    switch (viewMode) {
      case GalleryViewMode.search:
        return copyWith(searchCache: cache);
      case GalleryViewMode.popular:
        return copyWith(popularCache: cache);
      case GalleryViewMode.favorites:
        return updateFavoritesCache(favoritesSource, cache);
    }
  }

  OnlineGalleryState updateFavoritesCache(String source, ModeCache cache) {
    return source == 'gelbooru'
        ? copyWith(gelbooruFavoritesCache: cache)
        : copyWith(danbooruFavoritesCache: cache);
  }
}

/// 在线画廊 Notifier
@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  late Dio _dio;
  static const int _pageSize = 40;

  /// 用于取消正在进行的请求
  CancelToken? _cancelToken;

  @override
  OnlineGalleryState build() {
    // 保持状态在切换Tab时不被销毁
    ref.keepAlive();

    _dio = ref.read(onlineGalleryHttpClientProvider);

    return const OnlineGalleryState();
  }

  /// 取消当前正在进行的加载请求
  void _cancelCurrentRequest() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消请求');
    }
    _cancelToken = CancelToken();
  }

  /// 获取 API 服务
  DanbooruApiService get _apiService => ref.read(danbooruApiServiceProvider);

  /// 获取认证状态
  DanbooruAuthState get _authState => ref.read(danbooruAuthProvider);

  GelbooruApiService get _gelbooruApiService =>
      ref.read(gelbooruApiServiceProvider);

  GelbooruAuthState get _gelbooruAuthState => ref.read(gelbooruAuthProvider);

  // ==================== 视图模式切换 ====================

  /// 保存当前模式的滚动位置
  void saveScrollOffset(double offset) {
    final newCache = state.currentCache.copyWith(scrollOffset: offset);
    state = state.updateCurrentCache(newCache);
  }

  /// 切换到搜索模式（保留缓存数据）
  Future<void> switchToSearch() async {
    if (state.viewMode == GalleryViewMode.search) return;

    // 只切换模式，不清空数据
    state = state.copyWith(viewMode: GalleryViewMode.search);

    // 如果目标模式没有缓存数据，才加载
    if (state.searchCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  /// 切换到排行榜模式（保留缓存数据）
  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;

    // 只切换模式，不清空数据
    state = state.copyWith(viewMode: GalleryViewMode.popular);

    // 如果目标模式没有缓存数据，才加载
    if (state.popularCache.posts.isEmpty) {
      await _loadPopularPosts(refresh: true);
    }
  }

  /// 切换到收藏夹模式（保留缓存数据）
  Future<void> switchToFavorites() async {
    state = state.copyWith(viewMode: GalleryViewMode.favorites);
    final cache = state.favoritesCacheFor(state.favoritesSource);
    if (cache.posts.isEmpty) {
      await _loadFavorites(refresh: true);
    }
  }

  Future<void> setFavoritesSource(String source) async {
    if (source != 'danbooru' && source != 'gelbooru') return;
    if (state.favoritesSource == source) return;

    _cancelCurrentRequest();
    state = state.copyWith(
      favoritesSource: source,
      clearError: true,
      clearNotice: true,
    );
    if (state.viewMode == GalleryViewMode.favorites &&
        state.favoritesCacheFor(source).posts.isEmpty) {
      await _loadFavorites(refresh: true);
    }
  }

  // ==================== 排行榜功能 ====================

  /// 设置排行榜时间范围
  Future<void> setPopularScale(PopularScale scale) async {
    if (state.popularScale == scale) return;
    state = state.copyWith(popularScale: scale);
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPopularPosts(refresh: true);
    }
  }

  /// 设置排行榜日期
  Future<void> setPopularDate(DateTime? date) async {
    state = state.copyWith(popularDate: date, clearPopularDate: date == null);
    if (state.viewMode == GalleryViewMode.popular) {
      await _loadPopularPosts(refresh: true);
    }
  }

  /// 加载排行榜帖子
  Future<void> _loadPopularPosts({bool refresh = false}) async {
    // 取消之前的请求，支持打断
    _cancelCurrentRequest();

    final currentCache = state.popularCache;
    final page = refresh ? 1 : currentCache.page;

    // 更新加载状态，刷新时清空缓存
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      popularCache: refresh ? const ModeCache() : currentCache,
    );

    try {
      // 使用 order:rank 标签搜索实现排行榜功能（替代不稳定的 /explore 端点）
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      final blacklistTags = ref
          .read(onlineGalleryBlacklistNotifierProvider)
          .effectiveTags;
      final posts = await _apiService.searchPosts(
        tags: 'order:rank',
        page: page,
        limit: _pageSize,
      );

      // 过滤评级
      final filteredPosts = _filterByBlacklist(
        _filterByRatings(posts, state.selectedRatings),
        blacklistTags,
      );

      // 更新缓存
      final newCache = ModeCache(
        posts: refresh
            ? filteredPosts
            : [...currentCache.posts, ...filteredPosts],
        page: page,
        hasMore: posts.length >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );

      state = state.copyWith(isLoading: false, popularCache: newCache);
    } catch (e, stack) {
      // 如果是取消请求，重置加载状态但不显示错误
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = state.copyWith(isLoading: false);
        return;
      }
      AppLogger.e(
        'Failed to load popular posts: $e',
        e,
        stack,
        'OnlineGallery',
      );
      state = state.copyWith(
        isLoading: false,
        error: _getNetworkErrorMessage(e),
      );
    }
  }

  // ==================== 收藏夹功能 ====================

  /// 加载收藏夹
  Future<void> _loadFavorites({bool refresh = false}) async {
    if (state.favoritesSource == 'gelbooru') {
      await _loadGelbooruFavorites(refresh: refresh);
    } else {
      await _loadDanbooruFavorites(refresh: refresh);
    }
  }

  Future<void> _loadDanbooruFavorites({required bool refresh}) async {
    _cancelCurrentRequest();
    final authState = _authState;
    if (!authState.isLoggedIn || authState.user == null) {
      state = state.copyWith(error: '请先登录 Danbooru 账号');
      return;
    }

    final currentCache = state.danbooruFavoritesCache;
    final apiPage = _getNextPageParamForCache(
      refresh,
      currentCache,
      source: 'danbooru',
      viewMode: GalleryViewMode.favorites,
    );
    final statePage = refresh ? 1 : currentCache.page + 1;
    state = state
        .copyWith(isLoading: true, clearError: true)
        .updateFavoritesCache(
          'danbooru',
          refresh ? const ModeCache() : currentCache,
        );

    try {
      final (posts, rawCount) = await _fetchPosts(
        source: 'danbooru',
        query: 'ordfav:${authState.user!.name}',
        selectedRatings: state.selectedRatings,
        page: apiPage,
        includeDateRange: false,
      );
      final favoritedKeys = {...state.favoritedPostKeys};
      favoritedKeys.addAll(posts.map(onlineGalleryPostKey));
      final newCache = ModeCache(
        posts: refresh ? posts : [...currentCache.posts, ...posts],
        page: statePage,
        hasMore: rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );
      state = state
          .copyWith(isLoading: false, favoritedPostKeys: favoritedKeys)
          .updateFavoritesCache('danbooru', newCache);
    } catch (error, stack) {
      if (_isCancelled(error)) {
        state = state.copyWith(isLoading: false);
        return;
      }
      AppLogger.e(
        'Failed to load Danbooru favorites',
        error,
        stack,
        'OnlineGallery',
      );
      state = state.copyWith(
        isLoading: false,
        error: _getNetworkErrorMessage(error),
      );
    }
  }

  Future<void> _loadGelbooruFavorites({required bool refresh}) async {
    _cancelCurrentRequest();
    await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
    final authState = _gelbooruAuthState;
    if (!authState.isAuthenticated || authState.credentials == null) {
      state = state.copyWith(
        isLoading: false,
        errorCode: authState.status == GelbooruAuthStatus.invalid
            ? OnlineGalleryErrorCode.gelbooruCredentialsInvalid
            : OnlineGalleryErrorCode.gelbooruCredentialsRequired,
      );
      return;
    }

    final currentCache = state.gelbooruFavoritesCache;
    final pid = refresh ? 0 : currentCache.page;
    final statePage = refresh ? 1 : currentCache.page + 1;
    state = state
        .copyWith(isLoading: true, clearError: true)
        .updateFavoritesCache(
          'gelbooru',
          refresh ? const ModeCache() : currentCache,
        );

    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      final blacklistTags = ref
          .read(onlineGalleryBlacklistNotifierProvider)
          .effectiveTags;
      final result = await _gelbooruApiService.getFavorites(
        credentials: authState.credentials!,
        pid: pid,
        limit: _pageSize,
        cancelToken: _cancelToken,
      );
      final posts = _filterByBlacklist(
        _filterByRatings(result.posts, state.selectedRatings),
        blacklistTags,
      );
      final favoritedKeys = {...state.favoritedPostKeys};
      favoritedKeys.addAll(posts.map(onlineGalleryPostKey));
      final newCache = ModeCache(
        posts: refresh ? posts : [...currentCache.posts, ...posts],
        page: statePage,
        hasMore: result.rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );
      state = state
          .copyWith(isLoading: false, favoritedPostKeys: favoritedKeys)
          .updateFavoritesCache('gelbooru', newCache);
    } on GelbooruApiException catch (error, stack) {
      if (error.type == GelbooruApiErrorType.cancelled) {
        state = state.copyWith(isLoading: false);
        return;
      }
      if (error.type == GelbooruApiErrorType.invalidCredentials) {
        ref.read(gelbooruAuthProvider.notifier).markInvalid();
        invalidateGelbooruFavorites();
      }
      AppLogger.e(
        'Failed to load Gelbooru favorites',
        error,
        stack,
        'OnlineGallery',
      );
      state = state.copyWith(
        isLoading: false,
        errorCode: _gelbooruErrorCode(error.type),
      );
    }
  }

  /// 添加收藏
  Future<bool> addFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_authState.isLoggedIn) return false;
    final key = 'danbooru:$postId';

    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );

    final success = await _apiService.addFavorite(postId);
    final loadingKeys = {...state.favoriteLoadingPostKeys}..remove(key);

    if (success) {
      state = state.copyWith(
        favoritedPostKeys: {...state.favoritedPostKeys, key},
        favoriteLoadingPostKeys: loadingKeys,
      );
    } else {
      state = state.copyWith(favoriteLoadingPostKeys: loadingKeys);
    }
    return success;
  }

  /// 移除收藏
  Future<bool> removeFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_authState.isLoggedIn) return false;
    final key = 'danbooru:$postId';

    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );

    final success = await _apiService.removeFavorite(postId);
    final loadingKeys = {...state.favoriteLoadingPostKeys}..remove(key);

    if (success) {
      final newKeys = {...state.favoritedPostKeys}..remove(key);
      state = state.copyWith(
        favoritedPostKeys: newKeys,
        favoriteLoadingPostKeys: loadingKeys,
      );

      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSource == 'danbooru') {
        final currentCache = state.danbooruFavoritesCache;
        final newCache = currentCache.copyWith(
          posts: currentCache.posts.where((p) => p.id != postId).toList(),
        );
        state = state.updateFavoritesCache('danbooru', newCache);
      }
    } else {
      state = state.copyWith(favoriteLoadingPostKeys: loadingKeys);
    }
    return success;
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null) return false;
    if (state.favoritedPostKeys.contains('danbooru:$postId')) {
      return removeFavorite(postOrId);
    } else {
      return addFavorite(postOrId);
    }
  }

  /// 检查是否已收藏
  bool isFavorited(Object postOrId) {
    if (postOrId is DanbooruPost) {
      return state.favoritedPostKeys.contains(onlineGalleryPostKey(postOrId));
    }
    if (postOrId is int) {
      return state.favoritedPostKeys.contains('danbooru:$postOrId');
    }
    return false;
  }

  int? _danbooruFavoritePostId(Object postOrId) {
    if (postOrId is DanbooruPost) {
      if (postOrId.site != 'danbooru') return null;
      return postOrId.id;
    }
    if (postOrId is int) return postOrId;
    return null;
  }

  // ==================== 分页逻辑 ====================

  /// 获取下一页参数（基于缓存，Danbooru/Safebooru 使用 ID 分页，其他使用页码）
  dynamic _getNextPageParamForCache(
    bool refresh,
    ModeCache cache, {
    required String source,
    required GalleryViewMode viewMode,
  }) {
    if (refresh) return 1;

    // Gelbooru 和 Popular 模式必须使用页码分页
    if (source == 'gelbooru' || viewMode == GalleryViewMode.popular) {
      return cache.page + 1;
    }

    // Danbooru/Safebooru 搜索模式使用 ID 分页 (b{id})
    if (cache.posts.isNotEmpty) {
      return 'b${cache.posts.last.id}';
    }

    return 1;
  }

  // ==================== 通用功能 ====================

  /// 加载帖子（根据当前模式）
  Future<void> loadPosts({bool refresh = false}) async {
    switch (state.viewMode) {
      case GalleryViewMode.search:
        await _loadSearchPosts(refresh: refresh);
        break;
      case GalleryViewMode.popular:
        await _loadPopularPosts(refresh: refresh);
        break;
      case GalleryViewMode.favorites:
        await _loadFavorites(refresh: refresh);
        break;
    }
  }

  /// 加载搜索帖子
  Future<void> _loadSearchPosts({bool refresh = false}) async {
    // 取消之前的请求，支持打断
    _cancelCurrentRequest();

    final currentCache = state.searchCache;

    // 计算分页参数
    final apiPage = _getNextPageParamForCache(
      refresh,
      currentCache,
      source: state.source,
      viewMode: GalleryViewMode.search,
    );
    final statePage = refresh ? 1 : currentCache.page + 1;

    // 更新加载状态
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchCache: refresh ? const ModeCache() : currentCache,
    );

    try {
      // 1. 获取原始数据和过滤后的数据
      final searchQuery = buildOnlineGallerySearchQuery(
        state.searchQuery,
        fuzzyMatch: state.fuzzySearchEnabled,
      );
      final (posts, rawCount) = await _fetchPosts(
        source: state.source,
        query: searchQuery,
        selectedRatings: state.selectedRatings,
        page: apiPage,
      );

      // 更新缓存
      final newCache = ModeCache(
        posts: refresh ? posts : [...currentCache.posts, ...posts],
        page: statePage,
        hasMore: rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );

      state = state.copyWith(isLoading: false, searchCache: newCache);
    } catch (e, stack) {
      // 如果是取消请求，重置加载状态但不显示错误
      if (_isCancelled(e)) {
        state = state.copyWith(isLoading: false);
        return;
      }
      AppLogger.e('Failed to load posts', e, stack, 'OnlineGallery');
      state = state.copyWith(
        isLoading: false,
        error: e is GelbooruApiException ? null : _getNetworkErrorMessage(e),
        errorCode: e is GelbooruApiException
            ? _gelbooruErrorCode(e.type)
            : null,
      );
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadPosts();
  }

  /// 刷新
  Future<void> refresh() async {
    await loadPosts(refresh: true);
  }

  /// 跳转到指定页码
  Future<void> goToPage(int page) async {
    if (page < 1 || state.isLoading) return;

    if (state.viewMode == GalleryViewMode.popular) {
      state = state.copyWith(
        popularCache: ModeCache(page: page, hasMore: true),
      );
      await _loadPopularPosts();
      return;
    }

    final gelbooruSearch =
        state.viewMode == GalleryViewMode.search && state.source == 'gelbooru';
    final gelbooruFavorites =
        state.viewMode == GalleryViewMode.favorites &&
        state.favoritesSource == 'gelbooru';
    if (gelbooruSearch || gelbooruFavorites) {
      // Both Gelbooru endpoints use zero-based pid. Seed the cache with the
      // preceding page so the regular non-refresh loader requests this page.
      state = state.updateCurrentCache(
        ModeCache(page: page - 1, hasMore: true),
      );
      await loadPosts();
      return;
    }

    // Preserve the existing ID-based pagination behavior for Danbooru and
    // Safebooru, whose next-page token depends on the current result set.
    await loadPosts(refresh: true);
  }

  /// 搜索
  ///
  /// 支持：
  /// - 逗号分隔多个 tag（AND 逻辑，结果必须包含所有 tag）
  /// - 开启模糊匹配时自动添加通配符
  /// - 末尾逗号会被忽略
  Future<void> search(String query) async {
    // 立即取消当前请求，确保快速响应
    _cancelCurrentRequest();
    state = state.copyWith(
      searchQuery: query.trim(),
      viewMode: GalleryViewMode.search,
    );
    await loadPosts(refresh: true);
  }

  /// 设置模糊匹配开关
  Future<void> setFuzzySearchEnabled(bool enabled) async {
    if (state.fuzzySearchEnabled == enabled) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      fuzzySearchEnabled: enabled,
      viewMode: GalleryViewMode.search,
    );
    await loadPosts(refresh: true);
  }

  /// 设置数据源
  Future<void> setSource(String source) async {
    if (source != 'danbooru' && source != 'safebooru' && source != 'gelbooru') {
      return;
    }
    if (state.source == source) return;
    // 立即取消当前请求，确保快速响应
    _cancelCurrentRequest();
    state = state.copyWith(source: source);
    await loadPosts(refresh: true);
  }

  /// 设置评级筛选（多选）
  Future<void> setRatings(Set<String> selectedRatings) async {
    final normalized = _normalizeRatings(selectedRatings);
    if (_setEquals(state.selectedRatings, normalized)) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      selectedRatings: normalized,
      danbooruFavoritesCache: const ModeCache(),
      gelbooruFavoritesCache: const ModeCache(),
    );
    await loadPosts(refresh: true);
  }

  /// 切换单个评级（含“全部”逻辑）
  Future<void> toggleRating(String rating) async {
    if (rating == 'all') {
      await setRatings(kAllRatings);
      return;
    }

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

  /// 设置日期范围筛选（搜索模式）
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    // 立即取消当前请求，确保快速响应
    _cancelCurrentRequest();
    state = state.copyWith(
      dateRangeStart: start,
      dateRangeEnd: end,
      clearDateRange: start == null && end == null,
    );
    // 构建搜索查询
    await _applyDateRangeToSearch();
  }

  /// 清除日期范围
  Future<void> clearDateRange() async {
    // 立即取消当前请求，确保快速响应
    _cancelCurrentRequest();
    state = state.copyWith(clearDateRange: true);
    await loadPosts(refresh: true);
  }

  /// 应用日期范围到搜索
  Future<void> _applyDateRangeToSearch() async {
    if (state.viewMode != GalleryViewMode.search) return;
    await loadPosts(refresh: true);
  }

  /// 根据评级集合过滤帖子
  List<DanbooruPost> _filterByRatings(
    List<DanbooruPost> posts,
    Set<String> selectedRatings,
  ) {
    final normalized = _normalizeRatings(selectedRatings);
    if (normalized.length == kAllRatings.length) return posts;
    return posts.where((p) => normalized.contains(p.rating)).toList();
  }

  List<DanbooruPost> _filterByBlacklist(
    List<DanbooruPost> posts,
    Set<String> blacklistTags,
  ) {
    if (blacklistTags.isEmpty) return posts;
    return posts.where((post) {
      for (final tag in post.tags) {
        if (blacklistTags.contains(_normalizeTagForBlacklist(tag))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _appendBlacklistToQuery(String tags, Set<String> blacklistTags) {
    if (blacklistTags.isEmpty) return tags;

    // 请求级过滤仅做前置优化，本地过滤仍是最终兜底。
    final querySafeTags = blacklistTags
        .where(
          (tag) => tag.isNotEmpty && !tag.contains(':') && !tag.startsWith('-'),
        )
        .take(50)
        .toList();
    final blacklistExpr = querySafeTags.map((tag) => '-$tag').join(' ');
    if (blacklistExpr.isEmpty) return tags;
    return tags.isEmpty ? blacklistExpr : '$tags $blacklistExpr';
  }

  String _normalizeTagForBlacklist(String input) {
    return input.trim().toLowerCase().replaceAll(' ', '_');
  }

  void clearNotice() {
    state = state.copyWith(clearNotice: true);
  }

  void invalidateGelbooruFavorites() {
    state = state.copyWith(
      gelbooruFavoritesCache: const ModeCache(),
      favoritedPostKeys: state.favoritedPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
      favoriteLoadingPostKeys: state.favoriteLoadingPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
    );
  }

  bool _isCancelled(Object error) {
    return (error is DioException && error.type == DioExceptionType.cancel) ||
        (error is GelbooruApiException &&
            error.type == GelbooruApiErrorType.cancelled);
  }

  OnlineGalleryErrorCode _gelbooruErrorCode(GelbooruApiErrorType type) {
    switch (type) {
      case GelbooruApiErrorType.invalidCredentials:
        return OnlineGalleryErrorCode.gelbooruCredentialsInvalid;
      case GelbooruApiErrorType.rateLimited:
        return OnlineGalleryErrorCode.gelbooruRateLimited;
      case GelbooruApiErrorType.timeout:
        return OnlineGalleryErrorCode.gelbooruTimeout;
      case GelbooruApiErrorType.server:
        return OnlineGalleryErrorCode.gelbooruServer;
      case GelbooruApiErrorType.network:
        return OnlineGalleryErrorCode.gelbooruNetwork;
      case GelbooruApiErrorType.malformedResponse:
        return OnlineGalleryErrorCode.gelbooruMalformedResponse;
      case GelbooruApiErrorType.cancelled:
      case GelbooruApiErrorType.unknown:
        return OnlineGalleryErrorCode.gelbooruRequestFailed;
    }
  }

  /// 将网络错误转换为用户友好的提示信息
  String _getNetworkErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
          return '网络连接失败，请检查网络设置或代理配置';
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络请求超时，请检查网络连接';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 403) return '访问被拒绝，可能需要登录或权限不足';
          if (statusCode == 404) return '请求的资源不存在';
          if (statusCode == 429) return '请求过于频繁，请稍后再试';
          if (statusCode != null && statusCode >= 500) {
            return '服务器错误，请稍后再试';
          }
          return '请求失败 (${statusCode ?? '未知状态'})';
        case DioExceptionType.cancel:
          return '请求已取消';
        default:
          return '网络请求失败，请稍后重试';
      }
    }
    return '加载失败，请稍后重试';
  }

  /// 从 API 获取帖子，返回 (过滤后的列表, 原始数量)
  Future<(List<DanbooruPost>, int)> _fetchPosts({
    required String source,
    required String query,
    required Set<String> selectedRatings,
    required dynamic page,
    bool includeDateRange = true,
  }) async {
    await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .ensureInitialized();
    final blacklistTags = ref
        .read(onlineGalleryBlacklistNotifierProvider)
        .effectiveTags;

    // 构建标签查询
    String tags = query;
    final normalizedRatings = _normalizeRatings(selectedRatings);
    if (normalizedRatings.length < kAllRatings.length) {
      final ratingExpr = _buildRatingExpression(source, normalizedRatings);
      if (ratingExpr.isNotEmpty) {
        tags = tags.isEmpty ? ratingExpr : '$tags $ratingExpr';
      }
    }

    // 添加日期范围筛选（Danbooru 语法：date:start..end）
    if (includeDateRange &&
        state.dateRangeStart != null &&
        state.dateRangeEnd != null) {
      final startStr = _formatDateForQuery(state.dateRangeStart!);
      final endStr = _formatDateForQuery(state.dateRangeEnd!);
      final dateTag = 'date:$startStr..$endStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    } else if (includeDateRange && state.dateRangeStart != null) {
      final startStr = _formatDateForQuery(state.dateRangeStart!);
      final dateTag = 'date:>=$startStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    } else if (includeDateRange && state.dateRangeEnd != null) {
      final endStr = _formatDateForQuery(state.dateRangeEnd!);
      final dateTag = 'date:<=$endStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    }
    final baseTags = tags;
    final tagsWithBlacklist = _appendBlacklistToQuery(baseTags, blacklistTags);

    if (source == 'gelbooru') {
      return _fetchGelbooruPosts(
        tagsWithBlacklist: tagsWithBlacklist,
        baseTags: baseTags,
        normalizedRatings: normalizedRatings,
        blacklistTags: blacklistTags,
        page: page,
      );
    }

    final baseUrl = _getBaseUrl(source);
    final endpoint = _getEndpoint(source);

    AppLogger.d(
      'Fetching from $source: tags="$tagsWithBlacklist", page=$page',
      'OnlineGallery',
    );

    Future<Response<dynamic>> requestWithTags(String requestTags) {
      final queryParameters = <String, dynamic>{
        'tags': requestTags,
        'limit': _pageSize,
        'page': page,
      };

      return _dio.get(
        '$baseUrl$endpoint',
        queryParameters: queryParameters,
        options: Options(
          headers: {
            ...onlineGalleryImageHeadersForUrl('$baseUrl$endpoint'),
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
        cancelToken: _cancelToken,
      );
    }

    Response<dynamic> response;
    try {
      response = await requestWithTags(tagsWithBlacklist);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 422 && blacklistTags.isNotEmpty) {
        AppLogger.w(
          '422 with blacklist query, fallback to request without blacklist and filter locally',
          'OnlineGallery',
        );
        response = await requestWithTags(baseTags);
      } else {
        rethrow;
      }
    }

    final rawList = extractPostListFromResponse(response.data, source);
    if (rawList.isNotEmpty || response.data is List) {
      // 使用 compute 在独立 Isolate 中解析，避免主线程阻塞 UI
      final List<DanbooruPost> posts = await compute(parsePostsInIsolate, {
        'rawList': rawList,
        'source': source,
      });
      final filteredPosts = _filterByBlacklist(
        _filterByRatings(posts, normalizedRatings),
        blacklistTags,
      );

      AppLogger.d(
        'Fetched ${rawList.length} raw posts, ${filteredPosts.length} after filter',
        'OnlineGallery',
      );
      return (filteredPosts, rawList.length);
    }

    return (<DanbooruPost>[], 0);
  }

  Future<(List<DanbooruPost>, int)> _fetchGelbooruPosts({
    required String tagsWithBlacklist,
    required String baseTags,
    required Set<String> normalizedRatings,
    required Set<String> blacklistTags,
    required dynamic page,
  }) async {
    await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
    final authState = _gelbooruAuthState;
    if (!authState.isAuthenticated || authState.credentials == null) {
      return _fetchGelbooruHtmlPosts(
        tagsWithBlacklist: tagsWithBlacklist,
        baseTags: baseTags,
        normalizedRatings: normalizedRatings,
        blacklistTags: blacklistTags,
        page: page,
      );
    }

    Future<GelbooruPostPage> request(String requestTags) {
      return _gelbooruApiService.searchPosts(
        credentials: authState.credentials!,
        tags: _formatGelbooruTagsForRequest(requestTags),
        pid: _gelbooruApiPageToPid(page),
        limit: _pageSize,
        cancelToken: _cancelToken,
      );
    }

    try {
      GelbooruPostPage result;
      try {
        result = await request(tagsWithBlacklist);
      } on GelbooruApiException catch (error) {
        if (error.statusCode == 422 && blacklistTags.isNotEmpty) {
          result = await request(baseTags);
        } else {
          rethrow;
        }
      }
      final filteredPosts = _filterByBlacklist(
        _filterByRatings(result.posts, normalizedRatings),
        blacklistTags,
      );
      AppLogger.d(
        'Fetched ${result.rawCount} Gelbooru API posts, ${filteredPosts.length} after filter',
        'OnlineGallery',
      );
      return (filteredPosts, result.rawCount);
    } on GelbooruApiException catch (error) {
      if (error.type != GelbooruApiErrorType.invalidCredentials) rethrow;

      ref.read(gelbooruAuthProvider.notifier).markInvalid();
      invalidateGelbooruFavorites();
      state = state.copyWith(
        notice: OnlineGalleryNotice.gelbooruCredentialsInvalid,
      );
      AppLogger.w(
        'Gelbooru credentials were rejected; using public HTML for this search',
        'OnlineGallery',
      );
      return _fetchGelbooruHtmlPosts(
        tagsWithBlacklist: tagsWithBlacklist,
        baseTags: baseTags,
        normalizedRatings: normalizedRatings,
        blacklistTags: blacklistTags,
        page: page,
      );
    }
  }

  String _buildRatingExpression(String source, Set<String> normalizedRatings) {
    if (source == 'gelbooru') {
      // Gelbooru does not support Danbooru's rating:g shorthand in the web UI.
      // For multi-rating subsets, request broadly and apply the exact filter locally.
      if (normalizedRatings.length == 1) {
        return 'rating:${gelbooruRatingName(normalizedRatings.first)}';
      }
      return '';
    }

    return normalizedRatings.length == 1
        ? 'rating:${normalizedRatings.first}'
        : normalizedRatings.map((r) => '~rating:$r').join(' ');
  }

  int _gelbooruApiPageToPid(dynamic page) {
    final pageNumber = parseBooruInt(page) ?? 1;
    if (pageNumber <= 1) return 0;
    return pageNumber - 1;
  }

  int _gelbooruHtmlPageToPid(dynamic page) {
    final pageNumber = parseBooruInt(page) ?? 1;
    if (pageNumber <= 1) return 0;
    return (pageNumber - 1) * 42;
  }

  String _formatGelbooruTagsForRequest(String tags) {
    if (tags.trim().isEmpty) return tags;
    return tags
        .split(RegExp(r'\s+'))
        .map((tag) {
          final negative = tag.startsWith('-');
          final prefix = negative ? '-' : '';
          final body = negative ? tag.substring(1) : tag;
          final ratingMatch = RegExp(
            r'^rating:([a-zA-Z])$',
            caseSensitive: false,
          ).firstMatch(body);
          if (ratingMatch == null) return tag;
          return '${prefix}rating:${gelbooruRatingName(ratingMatch.group(1)!)}';
        })
        .join(' ');
  }

  Future<(List<DanbooruPost>, int)> _fetchGelbooruHtmlPosts({
    required String tagsWithBlacklist,
    required String baseTags,
    required Set<String> normalizedRatings,
    required Set<String> blacklistTags,
    required dynamic page,
  }) async {
    Future<Response<dynamic>> requestHtml(String requestTags) {
      return _dio.get(
        'https://gelbooru.com/index.php',
        queryParameters: {
          'page': 'post',
          's': 'list',
          'tags': _formatGelbooruTagsForRequest(requestTags),
          'pid': _gelbooruHtmlPageToPid(page),
        },
        options: Options(
          headers: {
            ...onlineGalleryImageHeadersForUrl(
              'https://gelbooru.com/index.php',
            ),
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'User-Agent': 'Mozilla/5.0 NAI-Launcher/1.0',
          },
          responseType: ResponseType.plain,
        ),
        cancelToken: _cancelToken,
      );
    }

    Response<dynamic> response;
    try {
      response = await requestHtml(tagsWithBlacklist);
    } on DioException catch (e) {
      if (blacklistTags.isNotEmpty && e.response?.statusCode == 422) {
        response = await requestHtml(baseTags);
      } else {
        rethrow;
      }
    }

    final html = response.data?.toString() ?? '';
    final posts = parseGelbooruHtmlPosts(html);
    final filteredPosts = _filterByBlacklist(
      _filterByRatings(posts, normalizedRatings),
      blacklistTags,
    );
    final postsWithDimensions = await _fillGelbooruThumbnailDimensions(
      filteredPosts,
    );

    AppLogger.d(
      'Fetched ${posts.length} Gelbooru HTML posts, ${filteredPosts.length} after filter',
      'OnlineGallery',
    );
    return (postsWithDimensions, posts.length);
  }

  Future<List<DanbooruPost>> _fillGelbooruThumbnailDimensions(
    List<DanbooruPost> posts,
  ) async {
    if (posts.isEmpty) return posts;

    final updatedPosts = List<DanbooruPost>.of(posts);
    var nextIndex = 0;
    final workerCount = updatedPosts.length < 6 ? updatedPosts.length : 6;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= updatedPosts.length) return;

        final post = updatedPosts[index];
        if (post.width > 0 && post.height > 0) continue;

        final size = await _fetchGelbooruThumbnailDimensions(post.previewUrl);
        if (size == null) continue;
        updatedPosts[index] = post.copyWith(
          width: size.width,
          height: size.height,
        );
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    return updatedPosts;
  }

  Future<({int width, int height})?> _fetchGelbooruThumbnailDimensions(
    String url,
  ) async {
    if (url.isEmpty) return null;

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            ...onlineGalleryImageHeadersForUrl(url),
            // Gelbooru HTML omits dimensions; the JPEG header provides enough
            // ratio data for the masonry layout without downloading originals.
            'Range': 'bytes=0-16383',
          },
        ),
        cancelToken: _cancelToken,
      );

      final data = response.data;
      if (data == null || data.isEmpty) return null;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      return decodeJpegDimensions(bytes);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      AppLogger.d(
        'Failed to read Gelbooru thumbnail dimensions: ${e.message}',
        'OnlineGallery',
      );
      return null;
    } catch (e) {
      AppLogger.d(
        'Failed to decode Gelbooru thumbnail dimensions: $e',
        'OnlineGallery',
      );
      return null;
    }
  }

  /// 格式化日期为 Danbooru 查询格式 (yyyy-MM-dd)
  String _formatDateForQuery(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Set<String> _normalizeRatings(Set<String> ratings) {
    final normalized = ratings.where(kAllRatings.contains).toSet();
    return Set.unmodifiable(normalized.isEmpty ? {...kAllRatings} : normalized);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// 获取基础 URL
  String _getBaseUrl(String source) {
    switch (source) {
      case 'danbooru':
        return 'https://danbooru.donmai.us';
      case 'safebooru':
        return 'https://safebooru.donmai.us';
      case 'gelbooru':
        return 'https://gelbooru.com';
      default:
        return 'https://danbooru.donmai.us';
    }
  }

  /// 获取 API 端点
  String _getEndpoint(String source) {
    switch (source) {
      case 'gelbooru':
        return '/index.php?page=dapi&s=post&q=index&json=1';
      default:
        return '/posts.json';
    }
  }
}
