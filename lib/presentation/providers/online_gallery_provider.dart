import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/models/online_gallery/danbooru_post.dart';
import '../../data/services/danbooru_auth_service.dart';

part 'online_gallery_provider.g.dart';

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
          return DanbooruPost(
            id: json['id'] as int? ?? 0,
            score: json['score'] as int? ?? 0,
            source: json['source'] as String? ?? '',
            md5: json['md5'] as String? ?? '',
            rating: json['rating'] as String? ?? 'g',
            width: json['width'] as int? ?? 0,
            height: json['height'] as int? ?? 0,
            tagString: json['tags'] as String? ?? '',
            fileExt: json['image']?.toString().split('.').last ?? 'jpg',
            fileUrl: json['file_url'] as String?,
            previewFileUrl: json['preview_url'] as String?,
            largeFileUrl: json['sample_url'] as String?,
          );
        }

        // Danbooru/Safebooru 使用标准字段
        return DanbooruPost.fromJson(json);
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
  final String searchQuery;
  final String source;
  final String rating;

  /// 视图模式
  final GalleryViewMode viewMode;

  /// 各模式独立缓存
  final ModeCache searchCache;
  final ModeCache popularCache;
  final ModeCache favoritesCache;

  /// 排行榜时间范围
  final PopularScale popularScale;

  /// 排行榜日期
  final DateTime? popularDate;

  /// 已收藏的帖子 ID 集合（用于快速查找）
  final Set<int> favoritedPostIds;

  /// 正在执行收藏操作的帖子 ID 集合
  final Set<int> favoriteLoadingPostIds;

  /// 日期范围筛选（搜索模式）
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  const OnlineGalleryState({
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.source = 'danbooru',
    this.rating = 'all',
    this.viewMode = GalleryViewMode.search,
    this.searchCache = const ModeCache(),
    this.popularCache = const ModeCache(),
    this.favoritesCache = const ModeCache(),
    this.popularScale = PopularScale.day,
    this.popularDate,
    this.favoritedPostIds = const {},
    this.favoriteLoadingPostIds = const {},
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
        return favoritesCache;
    }
  }

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
    String? searchQuery,
    String? source,
    String? rating,
    GalleryViewMode? viewMode,
    ModeCache? searchCache,
    ModeCache? popularCache,
    ModeCache? favoritesCache,
    PopularScale? popularScale,
    DateTime? popularDate,
    Set<int>? favoritedPostIds,
    Set<int>? favoriteLoadingPostIds,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearError = false,
    bool clearPopularDate = false,
    bool clearDateRange = false,
  }) {
    return OnlineGalleryState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      source: source ?? this.source,
      rating: rating ?? this.rating,
      viewMode: viewMode ?? this.viewMode,
      searchCache: searchCache ?? this.searchCache,
      popularCache: popularCache ?? this.popularCache,
      favoritesCache: favoritesCache ?? this.favoritesCache,
      popularScale: popularScale ?? this.popularScale,
      popularDate: clearPopularDate ? null : (popularDate ?? this.popularDate),
      favoritedPostIds: favoritedPostIds ?? this.favoritedPostIds,
      favoriteLoadingPostIds:
          favoriteLoadingPostIds ?? this.favoriteLoadingPostIds,
      dateRangeStart:
          clearDateRange ? null : (dateRangeStart ?? this.dateRangeStart),
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
        return copyWith(favoritesCache: cache);
    }
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

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

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
    if (!_authState.isLoggedIn) {
      state = state.copyWith(error: '请先登录 Danbooru 账号');
      return;
    }
    if (state.viewMode == GalleryViewMode.favorites) return;

    // 只切换模式，不清空数据
    state = state.copyWith(viewMode: GalleryViewMode.favorites);

    // 如果目标模式没有缓存数据，才加载
    if (state.favoritesCache.posts.isEmpty) {
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
    state = state.copyWith(
      popularDate: date,
      clearPopularDate: date == null,
    );
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
      final posts = await _apiService.searchPosts(
        tags: 'order:rank',
        page: page,
        limit: _pageSize,
      );

      // 过滤评级
      final filteredPosts = _filterByRating(posts);

      // 更新缓存
      final newCache = ModeCache(
        posts:
            refresh ? filteredPosts : [...currentCache.posts, ...filteredPosts],
        page: page,
        hasMore: posts.length >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );

      state = state.copyWith(
        isLoading: false,
        popularCache: newCache,
      );
    } catch (e, stack) {
      // 如果是取消请求，不显示错误
      if (e is DioException && e.type == DioExceptionType.cancel) {
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
    // 取消之前的请求，支持打断
    _cancelCurrentRequest();

    final authState = _authState;
    if (!authState.isLoggedIn || authState.user == null) {
      state = state.copyWith(error: '请先登录 Danbooru 账号');
      return;
    }

    final currentCache = state.favoritesCache;

    // 计算分页参数
    final apiPage = _getNextPageParamForCache(refresh, currentCache);
    final statePage = refresh ? 1 : currentCache.page + 1;

    // 更新加载状态
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      favoritesCache: refresh ? const ModeCache() : currentCache,
    );

    try {
      // 使用 ordfav:username 标签搜索收藏夹
      final (posts, rawCount) = await _fetchPosts(
        source: state.source,
        query: 'ordfav:${authState.user!.name}',
        rating: state.rating,
        page: apiPage,
      );

      // 更新收藏状态
      final favoritedIds = {...state.favoritedPostIds};
      for (final post in posts) {
        favoritedIds.add(post.id);
      }

      // 更新缓存
      final newCache = ModeCache(
        posts: refresh ? posts : [...currentCache.posts, ...posts],
        page: statePage,
        hasMore: rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );

      state = state.copyWith(
        isLoading: false,
        favoritesCache: newCache,
        favoritedPostIds: favoritedIds,
      );
    } catch (e, stack) {
      // 如果是取消请求，不显示错误
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      AppLogger.e('Failed to load favorites: $e', e, stack, 'OnlineGallery');
      state = state.copyWith(
        isLoading: false,
        error: _getNetworkErrorMessage(e),
      );
    }
  }

  /// 添加收藏
  Future<bool> addFavorite(int postId) async {
    if (!_authState.isLoggedIn) return false;

    // 设置 loading 状态
    state = state.copyWith(
      favoriteLoadingPostIds: {...state.favoriteLoadingPostIds, postId},
    );

    final success = await _apiService.addFavorite(postId);

    // 清除 loading 状态
    final loadingIds = {...state.favoriteLoadingPostIds};
    loadingIds.remove(postId);

    if (success) {
      state = state.copyWith(
        favoritedPostIds: {...state.favoritedPostIds, postId},
        favoriteLoadingPostIds: loadingIds,
      );
    } else {
      state = state.copyWith(favoriteLoadingPostIds: loadingIds);
    }
    return success;
  }

  /// 移除收藏
  Future<bool> removeFavorite(int postId) async {
    if (!_authState.isLoggedIn) return false;

    // 设置 loading 状态
    state = state.copyWith(
      favoriteLoadingPostIds: {...state.favoriteLoadingPostIds, postId},
    );

    final success = await _apiService.removeFavorite(postId);

    // 清除 loading 状态
    final loadingIds = {...state.favoriteLoadingPostIds};
    loadingIds.remove(postId);

    if (success) {
      final newIds = {...state.favoritedPostIds};
      newIds.remove(postId);
      state = state.copyWith(
        favoritedPostIds: newIds,
        favoriteLoadingPostIds: loadingIds,
      );

      // 如果在收藏夹视图中，从列表中移除
      if (state.viewMode == GalleryViewMode.favorites) {
        final currentCache = state.favoritesCache;
        final newCache = currentCache.copyWith(
          posts: currentCache.posts.where((p) => p.id != postId).toList(),
        );
        state = state.copyWith(favoritesCache: newCache);
      }
    } else {
      state = state.copyWith(favoriteLoadingPostIds: loadingIds);
    }
    return success;
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(int postId) async {
    if (state.favoritedPostIds.contains(postId)) {
      return await removeFavorite(postId);
    } else {
      return await addFavorite(postId);
    }
  }

  /// 检查是否已收藏
  bool isFavorited(int postId) {
    return state.favoritedPostIds.contains(postId);
  }

  // ==================== 分页逻辑 ====================

  /// 获取下一页参数（基于缓存，Danbooru/Safebooru 使用 ID 分页，其他使用页码）
  dynamic _getNextPageParamForCache(bool refresh, ModeCache cache) {
    if (refresh) return 1;

    // Gelbooru 和 Popular 模式必须使用页码分页
    if (state.source == 'gelbooru' ||
        state.viewMode == GalleryViewMode.popular) {
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
    final apiPage = _getNextPageParamForCache(refresh, currentCache);
    final statePage = refresh ? 1 : currentCache.page + 1;

    // 更新加载状态
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchCache: refresh ? const ModeCache() : currentCache,
    );

    try {
      // 1. 获取原始数据和过滤后的数据
      final (posts, rawCount) = await _fetchPosts(
        source: state.source,
        query: state.searchQuery,
        rating: state.rating,
        page: apiPage,
      );

      // 更新缓存
      final newCache = ModeCache(
        posts: refresh ? posts : [...currentCache.posts, ...posts],
        page: statePage,
        hasMore: rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : currentCache.scrollOffset,
      );

      state = state.copyWith(
        isLoading: false,
        searchCache: newCache,
      );
    } catch (e, stack) {
      // 如果是取消请求，不显示错误
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      AppLogger.e('Failed to load posts: $e', e, stack, 'OnlineGallery');
      state = state.copyWith(
        isLoading: false,
        error: _getNetworkErrorMessage(e),
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

    // 更新当前模式缓存的页码
    final newCache = state.currentCache.copyWith(page: page - 1);
    state = state.updateCurrentCache(newCache);

    await loadPosts(refresh: true);
  }

  /// 搜索
  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query.trim(),
      viewMode: GalleryViewMode.search,
    );
    await loadPosts(refresh: true);
  }

  /// 设置数据源
  Future<void> setSource(String source) async {
    if (state.source == source) return;
    state = state.copyWith(source: source);
    await loadPosts(refresh: true);
  }

  /// 设置评级筛选
  Future<void> setRating(String rating) async {
    if (state.rating == rating) return;
    state = state.copyWith(rating: rating);
    await loadPosts(refresh: true);
  }

  /// 设置日期范围筛选（搜索模式）
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
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
    state = state.copyWith(clearDateRange: true);
    await loadPosts(refresh: true);
  }

  /// 应用日期范围到搜索
  Future<void> _applyDateRangeToSearch() async {
    if (state.viewMode != GalleryViewMode.search) return;
    await loadPosts(refresh: true);
  }

  /// 根据评级过滤帖子
  List<DanbooruPost> _filterByRating(List<DanbooruPost> posts) {
    if (state.rating == 'all') return posts;
    return posts.where((p) => p.rating == state.rating).toList();
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
    required String rating,
    required dynamic page,
  }) async {
    final baseUrl = _getBaseUrl(source);
    final endpoint = _getEndpoint(source);

    // 构建标签查询
    String tags = query;
    if (rating != 'all') {
      tags = tags.isEmpty ? 'rating:$rating' : '$tags rating:$rating';
    }

    // 添加日期范围筛选（Danbooru 语法：date:start..end）
    if (state.dateRangeStart != null && state.dateRangeEnd != null) {
      final startStr = _formatDateForQuery(state.dateRangeStart!);
      final endStr = _formatDateForQuery(state.dateRangeEnd!);
      final dateTag = 'date:$startStr..$endStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    } else if (state.dateRangeStart != null) {
      final startStr = _formatDateForQuery(state.dateRangeStart!);
      final dateTag = 'date:>=$startStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    } else if (state.dateRangeEnd != null) {
      final endStr = _formatDateForQuery(state.dateRangeEnd!);
      final dateTag = 'date:<=$endStr';
      tags = tags.isEmpty ? dateTag : '$tags $dateTag';
    }

    AppLogger.d(
      'Fetching from $source: tags="$tags", page=$page',
      'OnlineGallery',
    );

    final response = await _dio.get(
      '$baseUrl$endpoint',
      queryParameters: {
        'tags': tags,
        'page': page,
        'limit': _pageSize,
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'NAI-Launcher/1.0',
        },
      ),
      cancelToken: _cancelToken,
    );

    if (response.data is List) {
      final rawList = response.data as List;

      // 使用 compute 在独立 Isolate 中解析，避免主线程阻塞 UI
      final List<DanbooruPost> posts = await compute(
        parsePostsInIsolate,
        {'rawList': rawList, 'source': source},
      );

      AppLogger.d(
        'Fetched ${rawList.length} raw posts, ${posts.length} after filter',
        'OnlineGallery',
      );
      return (posts, rawList.length);
    }

    return (<DanbooruPost>[], 0);
  }

  /// 格式化日期为 Danbooru 查询格式 (yyyy-MM-dd)
  String _formatDateForQuery(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
